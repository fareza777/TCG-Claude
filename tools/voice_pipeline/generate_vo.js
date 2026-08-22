// Voice-over generation for the Shardfall campaign.
//
//   set ELEVENLABS_API_KEY=...   (never stored in the repo)
//   node tools/voice_pipeline/generate_vo.js [--limit N] [--only ch1]
//
// Already-generated clips are skipped, because ElevenLabs bills per character
// and the quota only resets monthly: a rerun after a network hiccup must not
// pay for the same line twice.
const fs = require('fs');
const path = require('path');

const KEY = process.env.ELEVENLABS_API_KEY;
if (!KEY) {
  console.error('ELEVENLABS_API_KEY is not set.');
  process.exit(1);
}

const ROOT = path.resolve(__dirname, '..', '..');
const OUT = path.join(ROOT, 'app', 'assets', 'vo');
const narration = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'narration.json'), 'utf8'));
const voices = JSON.parse(
  fs.readFileSync(path.join(__dirname, 'voices.json'), 'utf8'));

// Flagship quality; the campaign is the first thing a new player hears.
const MODEL = 'eleven_multilingual_v2';
// 44.1kHz/64kbps mono keeps ~40 minutes of speech near 19MB in the APK.
const FORMAT = 'mp3_44100_64';

const args = process.argv.slice(2);
const limit = args.includes('--limit')
  ? Number(args[args.indexOf('--limit') + 1]) : Infinity;
const only = args.includes('--only') ? args[args.indexOf('--only') + 1] : null;

fs.mkdirSync(OUT, { recursive: true });

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function synth(clip) {
  const voiceId = voices[clip.voiceKey] || voices._default;
  const url = `https://api.elevenlabs.io/v1/text-to-speech/${voiceId}` +
    `?output_format=${FORMAT}`;

  for (let attempt = 1; attempt <= 4; attempt++) {
    const res = await fetch(url, {
      method: 'POST',
      headers: { 'xi-api-key': KEY, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        text: clip.text,
        model_id: MODEL,
        voice_settings: {
          stability: 0.45,      // a little variation so it does not drone
          similarity_boost: 0.8,
          style: 0.25,
          use_speaker_boost: true,
        },
      }),
    });

    if (res.ok) return Buffer.from(await res.arrayBuffer());

    const body = await res.text();
    // 429 is rate limiting; 5xx is transient. Anything else is a real error
    // and retrying would just burn quota.
    if (res.status !== 429 && res.status < 500) {
      throw new Error(`${clip.id}: HTTP ${res.status} ${body.slice(0, 200)}`);
    }
    const wait = 2000 * attempt;
    console.warn(`  ${clip.id}: HTTP ${res.status}, retry in ${wait}ms`);
    await sleep(wait);
  }
  throw new Error(`${clip.id}: gave up after 4 attempts`);
}

(async () => {
  let done = 0, skipped = 0, spent = 0, failed = 0;
  const todo = narration.clips
    .filter((c) => !only || c.chapter === only)
    .filter((c) => !fs.existsSync(path.join(OUT, `${c.id}.mp3`)));

  skipped = narration.clips.length - todo.length;
  const batch = todo.slice(0, limit);
  const chars = batch.reduce((s, c) => s + c.text.length, 0);

  console.log(`clips total   : ${narration.clips.length}`);
  console.log(`already done  : ${skipped}`);
  console.log(`generating    : ${batch.length} (${chars.toLocaleString()} chars)`);

  for (const clip of batch) {
    try {
      const audio = await synth(clip);
      fs.writeFileSync(path.join(OUT, `${clip.id}.mp3`), audio);
      done++;
      spent += clip.text.length;
      if (done % 20 === 0 || done === batch.length) {
        console.log(`  ${done}/${batch.length}  (${spent.toLocaleString()} chars)`);
      }
    } catch (err) {
      failed++;
      console.error(`  FAIL ${clip.id}: ${err.message}`);
    }
  }

  console.log(`DONE generated=${done} failed=${failed} chars=${spent.toLocaleString()}`);
})();
