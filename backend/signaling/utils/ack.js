// backend/signaling/utils/ack.js
export const ok = (ack, data) => ack?.({ ok: true, data });
export const fail = (ack, err) => {
  const e = typeof err === 'string' ? { message: err } : err;
  ack?.({ ok: false, error: e });
};