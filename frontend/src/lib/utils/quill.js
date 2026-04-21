import { uploadFile } from '$lib/utils/api';

const QUILL_CSS_ID = 'hkforum-quill-theme';
let quillLoader = null;

function ensureQuillCss() {
  if (document.getElementById(QUILL_CSS_ID)) return;
  const link = document.createElement('link');
  link.id = QUILL_CSS_ID;
  link.rel = 'stylesheet';
  link.href = 'https://cdn.jsdelivr.net/npm/quill@1.3.7/dist/quill.snow.css';
  document.head.appendChild(link);
}

function loadScript() {
  if (window.Quill) return Promise.resolve(window.Quill);
  if (quillLoader) return quillLoader;

  quillLoader = new Promise((resolve, reject) => {
    const script = document.createElement('script');
    script.src = 'https://cdn.jsdelivr.net/npm/quill@1.3.7/dist/quill.min.js';
    script.onload = () => resolve(window.Quill);
    script.onerror = () => reject(new Error('Failed to load Quill.'));
    document.body.appendChild(script);
  });

  return quillLoader;
}

export async function mountQuill({ root, toolbar, value, placeholder, uploadUrl, onChange }) {
  ensureQuillCss();
  const Quill = await loadScript();
  const quill = new Quill(root, {
    theme: 'snow',
    placeholder,
    modules: {
      toolbar: {
        container: toolbar,
        handlers: {
          image: async function imageHandler() {
            if (!uploadUrl) return;

            const input = document.createElement('input');
            input.type = 'file';
            input.accept = 'image/*';
            input.addEventListener(
              'change',
              async () => {
                const file = input.files?.[0];
                if (!file) return;
                const payload = await uploadFile(uploadUrl, file);
                const range = quill.getSelection(true);
                const index = range ? range.index : quill.getLength();
                quill.insertEmbed(index, 'image', payload.url, 'user');
                quill.setSelection(index + 1, 0, 'silent');
              },
              { once: true }
            );
            input.click();
          }
        }
      }
    }
  });

  if (value) {
    quill.root.innerHTML = value;
  }

  quill.on('text-change', () => {
    onChange(quill.root.innerHTML);
  });

  return quill;
}
