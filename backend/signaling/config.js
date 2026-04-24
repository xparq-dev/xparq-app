// signaling/config.js
export const ICE_SERVERS = [
  { urls: "stun:stun.l.google.com:19302" },
  { urls: "stun:stun1.l.google.com:19302" },
  { urls: "stun:stun2.l.google.com:19302" },
  /* 
  // Add your TURN server here for production
  {
    urls: [
      "turn:YOUR_TURN_DOMAIN:3478?transport=udp",
      "turn:YOUR_TURN_DOMAIN:3478?transport=tcp",
    ],
    username: "YOUR_USERNAME",
    credential: "YOUR_PASSWORD",
  },
  */
];