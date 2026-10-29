// Offline production. Requiring this module never makes API calls.
// node tools/voice_pipeline/generate_vo.js --provider deepgram --only vow
// --manifest FILE --out DIR --limit N --concurrency N --dry-run
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const {execFileSync}=require('child_process');
const ROOT=path.resolve(__dirname,'..','..');
function selectClips(clips,prefix){return clips.filter(c=>!prefix||(c.chapter||c.chapterId||'').startsWith(prefix));}
function validMp3(b){
  if(!b||b.length<512)return false;
  if(b.subarray(0,3).toString()==='ID3'){
    const size=((b[6]&127)<<21)|((b[7]&127)<<14)|((b[8]&127)<<7)|(b[9]&127);
    return b.length>size+14;
  }
  return b[0]===255&&(b[1]&224)===224;
}
function planProvider(requested,keys){
  if(!['auto','deepgram','elevenlabs'].includes(requested))throw Error('Invalid --provider');
  const chosen=requested==='auto'?(keys.elevenlabs?'elevenlabs':'deepgram'):requested;
  if(!keys[chosen])throw Error(`${chosen==='deepgram'?'DEEPGRAM':'ELEVENLABS'}_API_KEY is not set.`);
  return chosen;
}
function environment(name){
  if(process.env[name])return process.env[name];
  if(process.platform!=='win32')return undefined;
  if(!['ELEVENLABS_API_KEY','DEEPGRAM_API_KEY'].includes(name))throw Error('Unsupported environment key');
  try{return execFileSync('powershell.exe',['-NoProfile','-NonInteractive','-Command',
    `[Environment]::GetEnvironmentVariable('${name}','User')`],
    {encoding:'utf8',windowsHide:true,stdio:['ignore','pipe','ignore']}).trim()||undefined;}
  catch{return undefined;}
}
const sleep=ms=>new Promise(r=>setTimeout(r,ms));
async function synth(clip,provider,keys,eleven,deepgram){
  const model=deepgram[clip.voiceKey]||deepgram._default,voice=eleven[clip.voiceKey]||eleven._default;
  const url=provider==='deepgram'
    ?`https://api.deepgram.com/v1/speak?model=${encodeURIComponent(model)}&encoding=mp3&bit_rate=48000`
    :`https://api.elevenlabs.io/v1/text-to-speech/${encodeURIComponent(voice)}?output_format=mp3_44100_64`;
  for(let attempt=0;attempt<3;attempt++){
    let res;
    try{res=await fetch(url,{method:'POST',signal:AbortSignal.timeout(60000),
      headers:provider==='deepgram'?{'Authorization':`Token ${keys.deepgram}`,'Content-Type':'application/json'}:{'xi-api-key':keys.elevenlabs,'Content-Type':'application/json'},
      body:JSON.stringify(provider==='deepgram'?{text:clip.text}:{text:clip.text,model_id:'eleven_multilingual_v2',voice_settings:{stability:0.45,similarity_boost:0.8,style:0.25,use_speaker_boost:true}})});}
    catch{if(attempt<2){await sleep(1000*(attempt+1));continue;}throw Error(`${provider}: network request failed`);}
    if(res.ok){const b=Buffer.from(await res.arrayBuffer());if(!validMp3(b))throw Error(`${provider}: response was not a complete MP3`);return b;}
    // Provider bodies, URLs, credentials and headers never enter logs.
    if((res.status===429||res.status>=500)&&attempt<2){await sleep(1500*(attempt+1));continue;}
    throw Error(`${provider}: HTTP ${res.status}`);
  }
}
async function main(args=process.argv.slice(2)){
  const arg=(n,f)=>args.includes(n)?args[args.indexOf(n)+1]:f;
  const manifest=path.resolve(arg('--manifest',path.join(__dirname,'narration.json')));
  const out=path.resolve(arg('--out',path.join(ROOT,'app','assets','vo')));
  const prefix=arg('--only',null),requested=arg('--provider','auto'),limit=Number(arg('--limit',Infinity));
  const concurrency=Math.max(1,Math.min(4,Number(arg('--concurrency',2))));
  if(!(limit>=0)||!Number.isFinite(concurrency))throw Error('Invalid batch limits');
  const narration=JSON.parse(fs.readFileSync(manifest,'utf8').replace(/^\uFEFF/,''));
  const selected=selectClips(narration.clips,prefix);
  const pending=selected.filter(c=>{
    if(!/^[a-z0-9]+_\d+_[bpv]_\d+$/.test(c.id))throw Error('Invalid narration clip id');
    const target=path.join(out,`${c.id}.mp3`);
    return !fs.existsSync(target)||!validMp3(fs.readFileSync(target));
  });
  const todo=pending.slice(0,limit);
  console.log(`Selected=${selected.length} valid=${selected.length-pending.length} generating=${todo.length} characters=${todo.reduce((n,c)=>n+c.text.length,0)}`);
  if(args.includes('--dry-run')||todo.length===0)return;
  const keys={elevenlabs:environment('ELEVENLABS_API_KEY'),deepgram:environment('DEEPGRAM_API_KEY')};
  let provider=planProvider(requested,keys);
  const eleven=JSON.parse(fs.readFileSync(path.join(__dirname,'voices.json'),'utf8'));
  const deepgram=JSON.parse(fs.readFileSync(path.join(__dirname,'deepgram_voices.json'),'utf8'));
  const ledgerPath=path.join(__dirname,'production_ledger.json');
  const ledger=fs.existsSync(ledgerPath)?JSON.parse(fs.readFileSync(ledgerPath,'utf8')):{scopes:{},clips:{}};
  const scope=prefix||'*';
  if(ledger.scopes[scope]){
    if(requested!=='auto'&&provider!==ledger.scopes[scope])throw Error('Scope already has another cast provider; deliberate recasts require a new output directory.');
    provider=planProvider(ledger.scopes[scope],keys);
  }
  fs.mkdirSync(out,{recursive:true});let done=0;
  function persist(clip,b){
    const target=path.join(out,`${clip.id}.mp3`);
    fs.writeFileSync(target+'.tmp',b);fs.renameSync(target+'.tmp',target);
    ledger.scopes[scope]=provider;
    ledger.clips[clip.id]={provider,voice:provider==='deepgram'?(deepgram[clip.voiceKey]||deepgram._default):(eleven[clip.voiceKey]||eleven._default),textSha256:crypto.createHash('sha256').update(clip.text).digest('hex'),sha256:crypto.createHash('sha256').update(b).digest('hex'),bytes:b.length};
    fs.writeFileSync(ledgerPath,JSON.stringify(ledger,null,2));done++;
    if(done%20===0||done===todo.length)console.log(`Generated ${done}/${todo.length} with ${provider}`);
  }
  // Auto can fall back only before the first successful clip of a scope.
  // After that a failure stops the batch, so one character never changes cast.
  let first;
  try{first=await synth(todo[0],provider,keys,eleven,deepgram);}
  catch(e){
    if(requested==='auto'&&provider==='elevenlabs'&&keys.deepgram&&!ledger.scopes[scope]){
      console.log('ElevenLabs unavailable; selecting Deepgram for this complete scope.');
      provider='deepgram';first=await synth(todo[0],provider,keys,eleven,deepgram);
    }else throw e;
  }
  persist(todo[0],first);let cursor=1,failed=0,stopped=false;
  await Promise.all(Array.from({length:concurrency},async()=>{
    while(!stopped&&cursor<todo.length){const clip=todo[cursor++];
      try{persist(clip,await synth(clip,provider,keys,eleven,deepgram));}
      catch(e){failed++;stopped=true;console.error(`FAIL ${clip.id}: ${e.message}. Batch stopped; resume with the same provider.`);}
    }
  }));
  console.log(`DONE generated=${done} failed=${failed} provider=${provider}`);if(failed)process.exitCode=1;
}
module.exports={selectClips,validMp3,planProvider};
if(require.main===module)main().catch(e=>{console.error(e.message);process.exitCode=1;});
