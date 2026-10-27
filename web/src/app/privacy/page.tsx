/*
 * ============================================================================
 * DRAFT — NOT YET REVIEWED BY A LAWYER.
 *
 * This privacy policy is a reasonable starting draft written for LYO's
 * current features. The owner must review it with a qualified lawyer before
 * relying on it, and must fill in every [BRACKETED] placeholder (company
 * legal name, address, the AI and analytics providers actually in use).
 * Keep it in step with the iPhone app's privacy "nutrition label" and the
 * Google Play Data safety form — all three must describe the same thing.
 * ============================================================================
 */
import type { Metadata } from 'next';
import Link from 'next/link';
import { LegalPage, LegalSection, SUPPORT_EMAIL } from '@/components/legal/LegalPage';

export const metadata: Metadata = {
  title: 'Privacy Policy',
  description: 'How LYO collects, uses, shares and protects your information.',
  alternates: { canonical: '/privacy' },
};

export default function PrivacyPage() {
  return (
    <LegalPage
      title="Privacy Policy"
      updated="October 27, 2026"
      intro={
        <p>
          LYO (&quot;LYO&quot;, &quot;we&quot;, &quot;us&quot;) is an AI learning app available on the web at lyoai.app,
          on iPhone and on Android. This policy explains what information we collect when you use LYO,
          why we collect it, who we share it with, and the choices you have — including how to delete
          your account. LYO is operated by [COMPANY LEGAL NAME], [ADDRESS].
        </p>
      }
    >
      <LegalSection title="1. Information you give us">
        <ul>
          <li><strong>Account details</strong> — your email address, name, username and password (we store only a secure, one-way hash of your password, never the password itself).</li>
          <li><strong>Sign in with Google or Apple</strong> — if you choose one of these, we receive the basic profile the provider shares with us (usually your name, email address and a unique account ID). We never see your Google or Apple password. With Apple you may choose to hide your real email address.</li>
          <li><strong>Profile</strong> — anything you add, such as a display name, bio, photo, interests and learning goals.</li>
          <li><strong>Things you post</strong> — posts, comments, videos (&quot;clips&quot;), stories, images, study groups and events you create. Content you post publicly can be seen by other LYO users.</li>
          <li><strong>Messages</strong> — the direct messages you send and receive, so we can deliver them to the people you are talking to.</li>
          <li><strong>AI chat and lessons</strong> — the questions, answers, voice input and files you share with LYO&apos;s AI tutor, plus your quiz answers and learning progress.</li>
          <li><strong>Reports and support</strong> — reports you file about content or users, and anything you send us when you contact support.</li>
        </ul>
      </LegalSection>

      <LegalSection title="2. Information collected automatically">
        <ul>
          <li><strong>Device and usage information</strong> — app version, device type, operating system, language, time zone, IP address, and which features you use and when.</li>
          <li><strong>Location (only if you allow it)</strong> — to show learning communities, groups and events near you, we use your device&apos;s location when you grant permission. You can turn this off at any time in your device settings; the rest of LYO keeps working.</li>
          <li><strong>Push notification token</strong> — if you allow notifications, your device gives us a token so we can send you study reminders and activity alerts.</li>
          <li><strong>Analytics and crash reports</strong> — we use [ANALYTICS / CRASH REPORTING PROVIDERS, e.g. Firebase] to understand how LYO is used and to find and fix crashes. These reports include device details and what the app was doing when a problem happened.</li>
          <li><strong>Cookies and local storage</strong> — on the web we store your sign-in session and some preferences in your browser so you stay signed in.</li>
        </ul>
      </LegalSection>

      <LegalSection title="3. How we use your information">
        <ul>
          <li>To create and secure your account and keep you signed in.</li>
          <li>To provide LYO&apos;s features: AI tutoring, courses, quizzes, progress tracking, community, messaging and video.</li>
          <li>To personalize your learning — for example, recommending what to study next based on your progress.</li>
          <li>To send you notifications you have agreed to, and important service messages (such as password resets).</li>
          <li>To keep LYO safe: preventing spam, fraud and abuse, and reviewing reported content.</li>
          <li>To understand usage, fix bugs and improve LYO.</li>
          <li>To meet legal obligations.</li>
        </ul>
        <p>We do <strong>not</strong> sell your personal information, and we do not use it for third-party advertising.</p>
      </LegalSection>

      <LegalSection title="4. AI features and AI providers">
        <p>
          When you use LYO&apos;s AI tutor, chat, voice or lesson features, the content you send (your messages,
          voice recordings converted to text, files you attach, and relevant learning context) is sent to
          third-party AI model providers so they can generate a response. These providers currently include
          [LIST AI PROVIDERS, e.g. OpenAI, Google, Anthropic].
        </p>
        <p>
          We use these providers under agreements that only allow them to process your content to provide
          the service to us. Please do not share sensitive personal information (such as health, financial
          or government ID details) in AI chats. AI responses can be wrong — see our{' '}
          <Link href="/terms" className="text-violet-300 hover:underline">Terms of Service</Link>.
        </p>
      </LegalSection>

      <LegalSection title="5. Who we share information with">
        <ul>
          <li><strong>Other LYO users</strong> — your public profile and anything you post publicly. Direct messages are shared only with the people in the conversation.</li>
          <li><strong>Service providers</strong> who run LYO for us, such as cloud hosting and databases ([HOSTING PROVIDER, e.g. Railway]), sign-in and notifications (Google Firebase, Apple), file and video storage, email delivery, analytics and crash reporting, and the AI providers described above.</li>
          <li><strong>For legal reasons</strong> — when required by law, or to protect the safety and rights of our users, the public or LYO.</li>
          <li><strong>Business transfers</strong> — if LYO is involved in a merger, acquisition or sale of assets, your information may be transferred, and we will tell you before it becomes subject to a different policy.</li>
        </ul>
      </LegalSection>

      <LegalSection title="6. How long we keep information">
        <p>
          We keep your information while your account is open. When you delete your account, we delete or
          anonymize your personal information within [30] days, except where we must keep some of it for
          longer to meet legal obligations, resolve disputes, or deal with safety reports. Backups are
          overwritten on a rolling schedule of up to [35] days.
        </p>
      </LegalSection>

      <LegalSection title="7. Deleting your account">
        <p>
          You can delete your account at any time, from inside the app:
        </p>
        <ul>
          <li><strong>Web:</strong> Settings → Delete account.</li>
          <li><strong>Android:</strong> Settings → Delete account.</li>
          <li><strong>iPhone:</strong> Settings → Delete account.</li>
        </ul>
        <p>
          Deleting your account is permanent. It removes your profile, your posts, videos and comments, your
          messages, your AI chat history and your learning progress, and it cannot be undone. If you cannot
          sign in, email <a className="text-violet-300 hover:underline" href={`mailto:${SUPPORT_EMAIL}?subject=Account%20deletion%20request`}>{SUPPORT_EMAIL}</a> from
          the address on your account and we will delete it for you.
        </p>
      </LegalSection>

      <LegalSection title="8. Your choices and rights">
        <ul>
          <li>Change your profile information in Settings.</li>
          <li>Turn location and notifications on or off in your device settings.</li>
          <li>Block or report other users.</li>
          <li>
            Depending on where you live (for example in the European Union, the United Kingdom or California),
            you may have the right to access, correct, download or delete your personal information, and to
            object to or limit some processing. To make a request, email{' '}
            <a className="text-violet-300 hover:underline" href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
            We will not treat you differently for using these rights.
          </li>
        </ul>
      </LegalSection>

      <LegalSection title="9. Children">
        <p>
          LYO is not directed at children under 13, and we do not knowingly collect personal information from
          children under 13 (or under the minimum age required in your country). If you believe a child has
          given us personal information, contact us and we will delete it.
        </p>
      </LegalSection>

      <LegalSection title="10. Security">
        <p>
          We use reasonable technical and organizational measures to protect your information, including
          encryption in transit (HTTPS) and hashed passwords. No system is perfectly secure, so we cannot
          guarantee absolute security.
        </p>
      </LegalSection>

      <LegalSection title="11. International transfers">
        <p>
          LYO and its service providers may process your information in the United States and other
          countries, which may have different data protection laws than where you live. Where required, we
          use appropriate safeguards for these transfers.
        </p>
      </LegalSection>

      <LegalSection title="12. Changes to this policy">
        <p>
          We may update this policy from time to time. If we make significant changes, we will let you know in
          the app or by email before they take effect. The date at the top shows when it was last updated.
        </p>
      </LegalSection>

      <LegalSection title="13. Contact us">
        <p>
          Questions or requests about privacy: <a className="text-violet-300 hover:underline" href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>.
          For help with the app, visit <Link href="/support" className="text-violet-300 hover:underline">Support</Link>.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
