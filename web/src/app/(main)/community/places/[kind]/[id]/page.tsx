'use client'

import NodeDetailView from '@/components/community/NodeDetailView'
import { StateMessage } from '@/components/community/CommunityResults'
import { XCircle } from 'lucide-react'
import type { LearningNodeKind } from '@/types'

const PLACE_KINDS: LearningNodeKind[] = ['institution', 'study_group', 'private_lesson']

export default function CommunityPlacePage({ params }: { params: { kind: string; id: string } }) {
  const kind = params.kind as LearningNodeKind
  if (!PLACE_KINDS.includes(kind)) {
    return <StateMessage icon={XCircle} title="This is no longer available" body="The link may be incomplete." />
  }
  return <NodeDetailView kind={kind} nodeId={decodeURIComponent(params.id)} />
}
