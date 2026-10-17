import Link from 'next/link';

export const metadata = { title: 'Privacy Policy | LYO', description: 'How LYO handles account and learning information.' };

export default function PrivacyPage() {
  return (
    <main className="min-h-screen bg-[#0d0f18] px-5 py-12 text-white sm:py-16">
      <article className="mx-auto max-w-3xl space-y-8">
        <header className="space-y-3">
          <Link href="/" className="text-sm font-extrabold tracking-[0.2em] text-violet-300">LYO · HOME</Link>
          <h1 className="font-rounded text-4xl font-bold sm:text-5xl">Privacy Policy</h1>
          <p className="text-sm text-white/60">Last revised October 15, 2026 · For legal review before public release</p>
        </header>
        <div className="space-y-6 text-sm leading-7 text-white/75 sm:text-base">
          <section><h2 className="mb-2 text-xl font-bold text-white">1. What information LYO processes</h2><p>Information needed to operate the service can include account and profile information; messages, prompts and materials that you submit; course and classroom answers; test-preparation plans; interactions, progress and mastery records; media you choose to upload; and device, diagnostic and security information.</p></section>
          <section><h2 className="mb-2 text-xl font-bold text-white">2. How this information is used</h2><p>LYO uses account and learning information to authenticate you, provide lessons and AI responses, retain and restore study progress, personalize study recommendations, operate community features you elect to use, protect the service and investigate failures.</p></section>
          <section><h2 className="mb-2 text-xl font-bold text-white">3. AI and infrastructure providers</h2><p>Providing AI learning features may involve sending the prompt, relevant conversation context, attachments or lesson state to third-party AI and cloud infrastructure providers. Avoid entering information you do not want processed for your requested service. Third-party services may process data according to their contracts with the service operator.</p></section>
          <section><h2 className="mb-2 text-xl font-bold text-white">4. Sharing and public features</h2><p>Content you intentionally publish to social, creator or community surfaces may be visible to other users according to that feature's settings. Classroom and account records are not intended to be public merely because they are stored. Access controls are necessary to restrict private learning information.</p></section>
          <section><h2 className="mb-2 text-xl font-bold text-white">5. Retention and protection</h2><p>Account and learning records may be retained while needed to provide the service and to satisfy applicable operational, security and legal obligations. No service can guarantee absolute security. Account-deletion and data-access requests require identity verification before records are changed or disclosed.</p></section>
          <section><h2 className="mb-2 text-xl font-bold text-white">6. Cookies and local storage</h2><p>LYO's web experience uses browser storage for authentication and session continuity. Cookies and similar technologies may also be used where necessary for sign-in, security, diagnostics and service performance.</p></section>
          <section><h2 className="mb-2 text-xl font-bold text-white">7. Your options and requests</h2><p>You can request help accessing, correcting or deleting personal information through <a href="mailto:support@lyo.app" className="text-violet-300 underline underline-offset-4">support@lyo.app</a>. Rights, exceptions and verification requirements depend on applicable law and the nature of the request.</p></section>
          <section><h2 className="mb-2 text-xl font-bold text-white">8. Updates</h2><p>When privacy practices materially change, this page should be updated to reflect the current service and legal requirements. Please review it periodically.</p></section>
        </div>
        <footer className="border-t border-white/10 pt-6 text-sm text-white/65"><Link href="/terms" className="hover:text-white">Terms of Service</Link><span className="mx-3">·</span><Link href="/" className="hover:text-white">Back home</Link></footer>
      </article>
    </main>
  );
}
