import { Sidebar } from '@/components/layout/Sidebar';
import { TopBar } from '@/components/layout/TopBar';
import { MobileNav } from '@/components/layout/MobileNav';
import MainContent from '@/components/layout/MainContent';
import ClassroomCaptionSync from '@/components/classroom/ClassroomCaptionSync';
import ClassroomFlowControls from '@/components/classroom/ClassroomFlowControls';

export default function MainLayout({ children }: { children: React.ReactNode }) {
  return (
    <div className="flex h-screen">
      {/* Desktop sidebar — hidden on mobile */}
      <Sidebar />

      {/* Right column: topbar + scrollable content */}
      <div className="flex flex-col flex-1 overflow-hidden">
        <TopBar />

        <MainContent>{children}</MainContent>
      </div>

      {/* Mobile bottom nav — hidden on desktop */}
      <MobileNav />

      {/* Classroom-only compatibility layers: captions follow the real audio
          clock and transport/continue controls follow the real lesson state. */}
      <ClassroomCaptionSync />
      <ClassroomFlowControls />
    </div>
  );
}
