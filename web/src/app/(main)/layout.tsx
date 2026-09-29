import { Sidebar } from '@/components/layout/Sidebar';
import { TopBar } from '@/components/layout/TopBar';
import { MobileNav } from '@/components/layout/MobileNav';
import MainContent from '@/components/layout/MainContent';
import ClassroomCaptionSync from '@/components/classroom/ClassroomCaptionSync';

export default function MainLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen h-[100dvh]">
      {/* Desktop sidebar — hidden on mobile */}
      <Sidebar />

      {/* Right column: topbar + scrollable content */}
      <div className="flex flex-col flex-1 overflow-hidden">
        <TopBar />

        <MainContent>{children}</MainContent>
      </div>

      {/* Mobile bottom nav — hidden on desktop */}
      <MobileNav />

      {/* Classroom captions follow the real audio clock. */}
      <ClassroomCaptionSync />
    </div>
  );
}
