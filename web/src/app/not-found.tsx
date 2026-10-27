import Link from 'next/link';

export default function NotFound() {
  return (
    <main className="flex min-h-screen flex-col items-center justify-center bg-[#0d0f18] px-6 text-center text-white">
      <div className="mb-6 rounded-full border border-violet-400/30 bg-violet-500/10 px-5 py-2 text-sm font-bold tracking-[0.24em] text-violet-200">LYO</div>
      <p className="text-sm font-semibold uppercase tracking-[0.18em] text-violet-300">404 · Page not found</p>
      <h1 className="mt-4 max-w-xl font-rounded text-4xl font-extrabold leading-tight sm:text-5xl">This page isn't here.</h1>
      <p className="mt-5 max-w-md text-base text-white/65">The link may have changed. Your learning can continue from the LYO home page.</p>
      <Link href="/" className="mt-8 inline-flex min-h-12 items-center justify-center rounded-full bg-white px-7 text-sm font-bold text-[#0d0f18] transition hover:bg-violet-100 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-4 focus-visible:outline-violet-300">
        Back to LYO home
      </Link>
      <a className="mt-6 text-sm text-white/60 underline-offset-4 hover:underline" href="mailto:support@lyoai.app">Need help? Contact support</a>
    </main>
  );
}
