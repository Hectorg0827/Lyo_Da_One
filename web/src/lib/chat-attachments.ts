import type { ChatAttachment } from '@/types';

const ATTACHMENT_MARKDOWN = /!\[([^\]]*)\]\(([^)]+)\)|\[📎 ([^\]]+)\]\(([^)]+)\)/g;

function cleanName(name: string): string {
  return name.replace(/[\[\]()]/g, '').trim().slice(0, 120) || 'Attachment';
}

function inferMimeType(url: string, image: boolean): string {
  if (image) {
    if (/\.png(?:$|[?#])/i.test(url)) return 'image/png';
    if (/\.webp(?:$|[?#])/i.test(url)) return 'image/webp';
    if (/\.heic(?:$|[?#])/i.test(url)) return 'image/heic';
    return 'image/jpeg';
  }
  if (/\.pdf(?:$|[?#])/i.test(url)) return 'application/pdf';
  if (/\.csv(?:$|[?#])/i.test(url)) return 'text/csv';
  if (/\.md(?:$|[?#])/i.test(url)) return 'text/markdown';
  if (/\.json(?:$|[?#])/i.test(url)) return 'application/json';
  return 'text/plain';
}

function isLyoChatMediaUrl(url: string): boolean {
  try {
    const parsed = new URL(url, 'https://lyo.invalid');
    return parsed.pathname.startsWith('/api/v1/media/file/chat/');
  } catch {
    return false;
  }
}

export function buildCanonicalChatContent(text: string, attachments: ChatAttachment[]): string {
  const parts = text.trim() ? [text.trim()] : [];
  for (const attachment of attachments) {
    const name = cleanName(attachment.name);
    parts.push(
      attachment.kind === 'image'
        ? `![${name}](${attachment.url})`
        : `[📎 ${name}](${attachment.url})`
    );
  }
  return parts.join('\n\n');
}

export function parseCanonicalChatContent(content: string): {
  text: string;
  attachments: ChatAttachment[];
} {
  const attachments: ChatAttachment[] = [];
  const text = content.replace(
    ATTACHMENT_MARKDOWN,
    (match, imageName: string | undefined, imageUrl: string | undefined, fileName: string | undefined, fileUrl: string | undefined) => {
      const isImage = Boolean(imageUrl);
      const url = (imageUrl || fileUrl || '').trim();
      if (!isLyoChatMediaUrl(url)) return match;
      attachments.push({
        name: cleanName(imageName || fileName || 'Attachment'),
        url,
        mimeType: inferMimeType(url, isImage),
        size: 0,
        kind: isImage ? 'image' : 'document',
      });
      return '';
    }
  ).trim();
  return { text, attachments };
}
