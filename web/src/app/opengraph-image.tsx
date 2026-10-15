import { ImageResponse } from 'next/og';

export const runtime = 'edge';
export const alt = 'LYO — The Living AI Classroom. Learn with a live AI teacher.';
export const size = { width: 1200, height: 630 };
export const contentType = 'image/png';

export default function OpenGraphImage() {
  return new ImageResponse(
    (
      <div style={{ display: 'flex', width: '100%', height: '100%', padding: 88, color: '#ffffff', background: 'linear-gradient(135deg, #090d1b 0%, #261552 55%, #6032a3 100%)', flexDirection: 'column', justifyContent: 'center', fontFamily: 'sans-serif' }}>
        <div style={{ display: 'flex', fontSize: 35, fontWeight: 800, letterSpacing: 8, color: '#cbb6ff', marginBottom: 34 }}>LYO</div>
        <div style={{ display: 'flex', fontSize: 74, fontWeight: 800, lineHeight: 1.08, maxWidth: 940 }}>What do you want to learn?</div>
        <div style={{ display: 'flex', marginTop: 32, fontSize: 30, color: '#e8defe', maxWidth: 970 }}>Your living AI classroom. Learn, practice, and master anything.</div>
        <div style={{ display: 'flex', marginTop: 56, borderRadius: 40, background: '#ffffff', padding: '14px 26px', fontSize: 23, fontWeight: 700, color: '#22134c', alignSelf: 'flex-start' }}>lyoai.app</div>
      </div>
    ),
    { ...size },
  );
}
