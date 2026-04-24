require('dotenv').config();

const { createAudioSfuService } = require('./index');

async function runTest() {
  const sfu = await createAudioSfuService();

  const callId = 'test-call-1';
  const roomId = 'room-1';

  const userA = 'user-a';
  const userB = 'user-b';

  const peerA = 'peer-a';
  const peerB = 'peer-b';

  console.log('\n=== JOIN ROOM ===');

  await sfu.joinRoom({
    callId,
    roomId,
    peerId: peerA,
    userId: userA,
  });

  await sfu.joinRoom({
    callId,
    roomId,
    peerId: peerB,
    userId: userB,
  });

  console.log('✔ Peers joined');

  console.log('\n=== CREATE TRANSPORT ===');

  const sendTransport = await sfu.createWebRtcTransport({
    peerId: peerA,
    direction: 'send',
  });

  const recvTransport = await sfu.createWebRtcTransport({
    peerId: peerB,
    direction: 'recv',
  });

  console.log('✔ Transports created');

  console.log('\n=== PRODUCE AUDIO ===');

  const producer = await sfu.produceAudio({
    peerId: peerA,
    transportId: sendTransport.id,
    kind: 'audio',
  });

  console.log('✔ Producer created:', producer.id);

  console.log('\n=== CONSUME AUDIO ===');

  const consumer = await sfu.consumeAudio({
    peerId: peerB,
    producerId: producer.id,
    transportId: recvTransport.id,
  });

  console.log('✔ Consumer created:', consumer.id);

  console.log('\n🎉 TEST FLOW SUCCESS');
}

runTest().catch((err) => {
  console.error('\n❌ TEST FAILED');
  console.error(err);
});