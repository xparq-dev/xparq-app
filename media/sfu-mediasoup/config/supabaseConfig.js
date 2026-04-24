function getRequiredEnv(name) {
  const value = process.env[name];
  if (!value) {
    throw new Error(`Missing required environment variable: ${name}`);
  }
  return value;
}

function getSfuSupabaseConfig() {
  return {
    url: getRequiredEnv("SUPABASE_URL"),
    serviceRoleKey: getRequiredEnv("SUPABASE_SERVICE_ROLE_KEY"),
    schema: process.env.SFU_STATE_SCHEMA || "public",
  };
}

module.exports = {
  getSfuSupabaseConfig,
};
