'use client'

import NodeDetailView from '@/components/community/NodeDetailView'

export default function CommunityEventPage({ params }: { params: { id: string } }) {
  return <NodeDetailView kind="event" nodeId={decodeURIComponent(params.id)} />
}
