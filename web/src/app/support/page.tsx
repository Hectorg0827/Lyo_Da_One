/*
 * ============================================================================
 * DRAFT — the owner should review these answers before launch so they match
 * how the apps actually behave. The iPhone and Android store listings link
 * here as the "Support URL".
 * ============================================================================
 */
import type { Metadata } from 'next';
import Link from 'next/link';
import { LegalPage, LegalSection, SUPPORT_EMAIL } from '@/components/legal/LegalPage';

export const metadata: Metadata = {
  title: 'Support',
  description: 'Get help with LYO.',
  alternates: { canonical: '/support' },
};

export default function SupportPage() {
  return (
    <LegalPage
      title="Support"
      intro={
        <p>
          Need help with LYO? Email us at{' '}
          <a className="font-semibold text-violet-300 hover:underline" href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>{' '}
          and we will get back to you, usually within [2 business days]. Please include the email address on
          your LYO account and which device you are using (web, iPhone or Android).
        </p>
      }
    >
      <LegalSection title="I forgot my password">
        <p>
          On the login screen, choose <strong>Forgot password?</strong> and enter your email. We will send you a link to
          choose a new one. The link works once and expires after one hour. If you signed up with Google or Apple,
          use that button to sign in instead.
        </p>
      </LegalSection>

      <LegalSection title="How do I delete my account?">
        <p>
          Open <strong>Settings → Delete account</strong> on the web, iPhone or Android app and confirm. This permanently
          deletes your account and data and cannot be undone. If you cannot sign in, email{' '}
          <a className="text-violet-300 hover:underline" href={`mailto:${SUPPORT_EMAIL}?subject=Account%20deletion%20request`}>{SUPPORT_EMAIL}</a>{' '}
          from the address on your account and we will do it for you. See the{' '}
          <Link href="/privacy" className="text-violet-300 hover:underline">Privacy Policy</Link> for what is deleted.
        </p>
      </LegalSection>

      <LegalSection title="Someone is bothering me, or I saw something harmful">
        <p>
          Use <strong>Report</strong> on the post, video or profile, and <strong>Block</strong> to stop someone contacting you.
          You can manage blocked accounts in Settings. If anyone is in immediate danger, contact your local
          emergency services first.
        </p>
      </LegalSection>

      <LegalSection title="Notifications or location are not working">
        <p>
          Check that LYO is allowed to send notifications and use location in your device&apos;s settings. Location is only
          used to show communities and events near you, and LYO works without it.
        </p>
      </LegalSection>

      <LegalSection title="Privacy and data requests">
        <p>
          To ask for a copy of your data or to correct it, email{' '}
          <a className="text-violet-300 hover:underline" href={`mailto:${SUPPORT_EMAIL}`}>{SUPPORT_EMAIL}</a>. Read more in our{' '}
          <Link href="/privacy" className="text-violet-300 hover:underline">Privacy Policy</Link> and{' '}
          <Link href="/terms" className="text-violet-300 hover:underline">Terms of Service</Link>.
        </p>
      </LegalSection>
    </LegalPage>
  );
}
