/*
 * ============================================================================
 * DRAFT — NOT YET REVIEWED BY A LAWYER.
 *
 * These terms of service are a reasonable starting draft written for LYO's
 * current features. The owner must review them with a qualified lawyer
 * before relying on them, and must fill in every [BRACKETED] placeholder
 * (company legal name, governing law, dispute process). Paid features are
 * deliberately not covered yet; add billing terms when payments launch.
 * ============================================================================
 */
import type { Metadata } from 'next';
import Link from 'next/link';
import { LegalPage, LegalSection, SUPPORT_EMAIL } from '@/components/legal/LegalPage';

export const metadata: Metadata = {
  title: 'Terms of Service',
  description: 'The rules for using LYO.',
  alternates: { canonical: '/terms' },
};

export default function TermsPage() {
  return (
    <LegalPage
      title="Terms of Service"
      updated="October 27, 2026"
      intro={
        <p>
          These terms are an agreement between you and [COMPANY LEGAL NAME] (&quot;LYO&quot;, &quot;we&quot;, &quot;us&quot;)
          about your use of LYO on the web, iPhone and Android. By creating an account or using LYO, you agree
          to these terms and to our <Link href="/privacy" className="text-violet-300 hover:underline">Privacy Policy</Link>.
          If you do not agree, please do not use LYO.
        </p>
      }
    >
      <LegalSection title="1. Who can use LYO">
        <p>
          You must be at least 13 years old (or the minimum age in your country) to use LYO. If you are under
          18, you need permission from a parent or guardian, who also agrees to these terms.
        </p>
      </LegalSection>

      <LegalSection title="2. Your account">
        <ul>
          <li>Give accurate information when you sign up, and keep your password safe.</li>
          <li>You are responsible for what happens on your account. Tell us right away at {SUPPORT_EMAIL} if you think someone else is using it.</li>
          <li>You can delete your account at any time in Settings → Delete account. Deletion is permanent.</li>
        </ul>
      </LegalSection>

      <LegalSection title="3. Your content">
        <p>
          You own the posts, videos, comments, messages and other content you create on LYO (&quot;your content&quot;).
          So that we can run the service, you give LYO a worldwide, non-exclusive, royalty-free license to host,
          store, copy, display, adapt (for example, resize or transcode a video) and distribute your content
          within LYO, and to show public content to other users. This license ends when you delete the content
          or your account, except for copies other users have already shared or that we must keep by law.
        </p>
        <p>You promise that you have the rights to everything you post, and that it follows these terms.</p>
      </LegalSection>

      <LegalSection title="4. Community rules">
        <p>When using LYO, you agree not to:</p>
        <ul>
          <li>Harass, bully, threaten or impersonate anyone, or post hateful content.</li>
          <li>Post sexual content involving minors (we report this to the authorities), or any sexually explicit or graphically violent content.</li>
          <li>Post spam, scams, malware, or content you do not have the rights to.</li>
          <li>Share someone else&apos;s private information without their permission.</li>
          <li>Use LYO to cheat on graded work where that is not allowed, or to break the law.</li>
          <li>Try to hack, overload, scrape or reverse-engineer LYO, or get around its limits or safety features.</li>
        </ul>
        <p>
          You can report content and block other users inside the app. We may remove content, limit features,
          or suspend or close accounts that break these rules.
        </p>
      </LegalSection>

      <LegalSection title="5. AI features">
        <ul>
          <li>LYO uses artificial intelligence to tutor, explain, quiz and create lessons. <strong>AI can make mistakes.</strong> Check important information with trusted sources.</li>
          <li>AI output is for learning only. It is not professional advice (medical, legal, financial or otherwise).</li>
          <li>What you send to the AI is processed by third-party AI providers as described in our <Link href="/privacy" className="text-violet-300 hover:underline">Privacy Policy</Link>.</li>
          <li>Do not use AI features to create content that breaks the community rules above.</li>
        </ul>
      </LegalSection>

      <LegalSection title="6. LYO's property">
        <p>
          LYO&apos;s app, design, logo, courses we create, and software belong to LYO or its licensors. We give you
          a personal, non-transferable, revocable license to use LYO as these terms allow. Please do not copy or
          resell it.
        </p>
      </LegalSection>

      <LegalSection title="7. Other services">
        <p>
          LYO works with other services such as Google and Apple sign-in, app stores, maps and video hosts.
          Your use of those services is also covered by their own terms. We are not responsible for them.
        </p>
      </LegalSection>

      <LegalSection title="8. Ending your use of LYO">
        <p>
          You can stop using LYO and delete your account at any time. We may suspend or end your access if you
          break these terms, if required by law, or if we stop offering LYO. Where reasonable, we will tell you
          first.
        </p>
      </LegalSection>

      <LegalSection title="9. Disclaimers">
        <p>
          LYO is provided &quot;as is&quot; and &quot;as available&quot;. To the extent the law allows, we make no promises that
          LYO will always be available, error-free, or that its content (including AI content) is accurate or
          complete.
        </p>
      </LegalSection>

      <LegalSection title="10. Limitation of liability">
        <p>
          To the extent the law allows, LYO will not be liable for indirect, incidental, special or consequential
          damages, or for lost data or profits, arising from your use of LYO. Our total liability for any claim is
          limited to the greater of the amount you paid us in the 12 months before the claim or [US $50]. Some
          places do not allow these limits, so they may not apply to you.
        </p>
      </LegalSection>

      <LegalSection title="11. Governing law and disputes">
        <p>
          These terms are governed by the laws of [STATE / COUNTRY]. [DISPUTE RESOLUTION PROCESS — to be decided
          with a lawyer.] Before filing a claim, please contact us at {SUPPORT_EMAIL} so we can try to resolve it.
        </p>
      </LegalSection>

      <LegalSection title="12. Changes to these terms">
        <p>
          We may update these terms. If changes are significant, we will tell you in the app or by email before
          they take effect. If you keep using LYO after that, you accept the new terms.
        </p>
      </LegalSection>

      <LegalSection title="13. Contact">
        <p>
          Email <a className="text-violet-300 hover:underline" href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>, or
          visit <Link href="/support" className="text-violet-300 hover:underline">Support</Link>.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
