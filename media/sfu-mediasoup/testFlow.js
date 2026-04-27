require('dotenv').config();

const { createAudioSfuService } = require('./index');

async function runTest() {
  const sfu = await createAudioSfuService();

  const callId = 'a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab';
  const roomId = 'room_a1b2c3d4-e5f6-4a5b-8c9d-0123456789ab';

  const userA = '00000000-0000-0000-0000-000000000001';
  const userB = '00000000-0000-0000-0000-000000000002';

  const peerA = 'peer-a-uuid';
  const peerB = 'peer-b-uuid';

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