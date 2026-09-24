'use client';

import Link from 'next/link';
import { classifyUntrustedLink } from '@/lib/untrusted-links.mjs';

/**
 * An anchor built from a URL this app did not author.
 *
 * Three kinds of URL reach this app's anchors without a developer ever seeing
 * them: model-produced links inside chat and lesson text, server-written ones
 * like the Test Prep handoff, and URLs one learner typed that another
 * learner's browser will render — a community event's meeting link.
 *
 * None of them were scheme-checked. `<a href="javascript:…">` executes on
 * click, so every one of those sites was a click away from running whatever
 * the URL said, in the victim's session. The community case is the sharpest,
 * because there the author and the reader are different people.
 *
 * This is the one place that decides. A URL that is not http, https or mailto
 * does not become an anchor at all: the label still renders, so nothing
 * disappears from the page, but there is nothing to click.
 *
 * Links to our own origin are handed to the router instead of reloading the
 * app. External ones open in a new tab and carry `rel="noopener noreferrer"` —
 * `noreferrer` alone happens to imply it in current browsers, but stating both
 * is what makes the intent survive someone later needing the referrer.
 */
export default function UntrustedLink({
  href,
  className,
  children,
  title,
}: {
  href?: string | null;
  className?: string;
  children: React.ReactNode;
  title?: string;
}) {
  const link = classifyUntrustedLink(href);

  if (link.kind === 'unsafe') {
    return <span className={className} title={title}>{children}</span>;
  }
  if (link.kind === 'internal') {
    return <Link href={link.href} className={className} title={title}>{children}</Link>;
  }
  return (
    <a
      href={link.href}
      target="_blank"
      rel="noopener noreferrer"
      className={className}
      title={title}
    >
      {children}
    </a>
  );
}
