import { defineConfig } from 'astro/config';

// Dependency-free remark plugin: turn [[id]] and [[id|label]] into links to /entry/id.
// This is the prose cross-link mechanism (the Civilopedia "rabbit hole"). The build-time
// referential check lives in the export script; broken links surface there.
function remarkWikiLinks() {
  const re = /\[\[([^\]|]+?)(?:\|([^\]]+?))?\]\]/g;
  const walk = (node) => {
    if (!node.children) return;
    const out = [];
    for (const child of node.children) {
      if (child.type === 'text' && child.value.includes('[[')) {
        re.lastIndex = 0;
        let last = 0, m, matched = false;
        while ((m = re.exec(child.value))) {
          matched = true;
          if (m.index > last) out.push({ type: 'text', value: child.value.slice(last, m.index) });
          const id = m[1].trim();
          const label = (m[2] || m[1]).trim();
          out.push({ type: 'link', url: `/entry/${id}`, children: [{ type: 'text', value: label }] });
          last = m.index + m[0].length;
        }
        if (matched) {
          if (last < child.value.length) out.push({ type: 'text', value: child.value.slice(last) });
        } else {
          out.push(child);
        }
      } else {
        walk(child);
        out.push(child);
      }
    }
    node.children = out;
  };
  return (tree) => walk(tree);
}

export default defineConfig({
  markdown: { remarkPlugins: [remarkWikiLinks] },
});
