// Week 6, step 5: the sender. The trigger notify_assignment calls it with the
// project's secret key when the office assigns an entrance; it sends one FCM
// message per phone of the assigned worker and deletes addresses FCM rejects.
import "@supabase/functions-js/edge-runtime.d.ts";
import { withSupabase } from "@supabase/server";
import { JWT } from "google-auth-library";
import { assignmentMessage, isDeadToken } from "./message.ts";

// The service-account key of your Firebase project, set with
// `supabase secrets set --env-file`. It never goes in the repo or the app.
const serviceAccount = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT") ?? "null");

async function accessToken(): Promise<string> {
  const jwt = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ["https://www.googleapis.com/auth/firebase.messaging"],
  });
  const { access_token } = await jwt.authorize();
  return access_token!;
}

export default {
  // auth: "secret": only a caller holding the project's secret key gets in
  // (the trigger, or you from PowerShell); ctx.supabaseAdmin bypasses RLS.
  fetch: withSupabase({ auth: "secret" }, async (req, ctx) => {
    if (!serviceAccount) {
      return Response.json({ error: "FCM_SERVICE_ACCOUNT is not set" }, { status: 500 });
    }
    const { entrance_id, user_id } = await req.json();

    const { data: entrance, error } = await ctx.supabaseAdmin
      .from("entrances")
      .select("id, street, number, entrance_name")
      .eq("id", entrance_id)
      .single();
    if (error) return Response.json({ error: error.message }, { status: 404 });

    const { data: rows } = await ctx.supabaseAdmin
      .from("push_tokens")
      .select("token")
      .eq("user_id", user_id);
    if (!rows?.length) return Response.json({ sent: 0, removed: 0 });

    const bearer = await accessToken();
    const url = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
    let sent = 0;
    let removed = 0;
    for (const { token } of rows) {
      const res = await fetch(url, {
        method: "POST",
        headers: { "Content-Type": "application/json", Authorization: `Bearer ${bearer}` },
        body: JSON.stringify(assignmentMessage(token, entrance)),
      });
      const body = await res.json();
      if (res.ok) sent++;
      else if (isDeadToken(res.status, body)) {
        await ctx.supabaseAdmin.from("push_tokens").delete().eq("token", token);
        removed++;
      } else console.error("FCM refused", res.status, JSON.stringify(body));
    }
    return Response.json({ sent, removed });
  }),
};
