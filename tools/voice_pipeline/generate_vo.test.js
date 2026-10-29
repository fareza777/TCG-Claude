const {test} = require('node:test');
const assert = require('node:assert/strict');
const {selectClips, validMp3, planProvider} = require('./generate_vo');
test('prefix selects expansion without selecting old chapters', () => {
  assert.deepEqual(selectClips([{chapter:'vow01'},{chapter:'vow20'},{chapter:'ch1'}], 'vow').map(c=>c.chapter), ['vow01','vow20']);
});
test('resume rejects JSON, empty and truncated audio', () => {
  assert.equal(validMp3(Buffer.from('{"error":"quota"}')),false);
  assert.equal(validMp3(Buffer.alloc(10)),false);
  const audio=Buffer.alloc(1000); audio[0]=0xff;audio[1]=0xfb;
  assert.equal(validMp3(audio),true);
});
test('explicit provider never silently changes the cast', () => {
  assert.equal(planProvider('deepgram',{deepgram:'key',elevenlabs:'key'}),'deepgram');
  assert.throws(()=>planProvider('deepgram',{elevenlabs:'key'}),/DEEPGRAM_API_KEY/);
  assert.equal(planProvider('auto',{deepgram:'key'}),'deepgram');
  assert.equal(planProvider('auto',{deepgram:'key',elevenlabs:'key'}),'elevenlabs');
});
