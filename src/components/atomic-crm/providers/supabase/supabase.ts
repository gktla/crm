import type { SupabaseClient } from "@supabase/supabase-js";
import { createClient } from "@supabase/supabase-js";

let supabaseClient: SupabaseClient | null = null;

export const getSupabaseClient = () => {
  if (!supabaseClient) {
    supabaseClient = createClient(
      import.meta.env.VITE_SUPABASE_URL,
      import.meta.env.VITE_SB_PUBLISHABLE_KEY,
      {
        auth: {
          // Use the implicit flow so OAuth (e.g. Google) returns tokens in the
          // URL hash. The app's auth callback (`public/auth-callback.html` +
          // ra-supabase `handleCallback`) is hash-based; the default PKCE flow
          // returns a `?code=` query param it cannot consume, which silently
          // drops the session and bounces the user back to the login page.
          flowType: "implicit",
        },
      },
    );
  }
  return supabaseClient;
};
