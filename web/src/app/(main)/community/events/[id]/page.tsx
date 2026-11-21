'use client'

import { useParams } from 'next/navigation'
import NodeDetailView from '@/components/community/NodeDetailView'

export default function CommunityEventPage() {
  const params = useParams<{ id: string }>()
  return <NodeDetailView kind="event" nodeId={decodeURIComponent(params.id)} />
}
