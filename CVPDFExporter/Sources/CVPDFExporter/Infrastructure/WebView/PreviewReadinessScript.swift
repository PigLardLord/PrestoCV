import Foundation

public enum PreviewReadinessScript {

    public static let bootstrap: String = """
        (function() {
            if (window.__cvPreview && window.__cvPreview.awaitReady) { return; }

            let readinessPromise;
            const awaitReady = () => readinessPromise;

            const awaitFonts = () => {
                if (document.fonts && document.fonts.ready) {
                    return document.fonts.ready.catch(() => {});
                }
                return Promise.resolve();
            };

            const awaitImages = () => {
                const images = Array.from(document.images || []);
                if (images.length === 0) { return Promise.resolve(); }
                return Promise.all(images.map(image => {
                    if (image.complete) { return Promise.resolve(); }
                    return new Promise(resolve => {
                        image.addEventListener('load', resolve, { once: true });
                        image.addEventListener('error', resolve, { once: true });
                    });
                }));
            };

            const awaitDom = () => {
                if (document.readyState === 'complete') {
                    return Promise.resolve();
                }
                return new Promise(resolve => {
                    window.addEventListener('load', () => resolve(), { once: true });
                });
            };

            const contentPromise = Promise.all([awaitDom(), awaitFonts(), awaitImages()]);
            readinessPromise = contentPromise
                .then(() => new Promise(resolve => requestAnimationFrame(() => requestAnimationFrame(resolve))));

            window.__cvPreview = window.__cvPreview || {};
            window.__cvPreview.awaitReady = awaitReady;
            window.__cvPreview.awaitContent = () => contentPromise;
        })();
    """

    public static let awaitReady: String = "window.__cvPreview && window.__cvPreview.awaitReady ? window.__cvPreview.awaitReady() : Promise.resolve(true);"

    /// The body of a function that resolves to true once the page's document, fonts and images are ready, for
    /// `callAsyncJavaScript`, which waits on the promise a function body returns. It leaves out the animation frames that
    /// `awaitReady` waits for after them: a web view that is not shown may never run them.
    static let awaitContentFunctionBody: String =
        "return (window.__cvPreview && window.__cvPreview.awaitContent ? window.__cvPreview.awaitContent() : Promise.resolve()).then(() => true);"

    public static let scalingBootstrap: String = """
        (function() {
            window.__cvPreview = window.__cvPreview || {};

            const computeScale = () => {
                const shell = document.querySelector('.cv-preview-shell');
                const stage = document.querySelector('.cv-preview-stage');
                const page = document.querySelector('.cv-preview-page');
                const content = document.querySelector('.cv-preview-content');
                if (!shell || !stage || !page || !content) { return null; }

                if (!content.dataset.cvBaseWidth || !content.dataset.cvBaseHeight) {
                    const rect = content.getBoundingClientRect();
                    content.dataset.cvBaseWidth = rect.width;
                    content.dataset.cvBaseHeight = rect.height;
                }

                const baseWidth = parseFloat(content.dataset.cvBaseWidth || '0');
                const baseHeight = parseFloat(content.dataset.cvBaseHeight || '0');
                if (baseWidth <= 0 || baseHeight <= 0) { return null; }

                const availableWidth = shell.clientWidth;
                if (availableWidth <= 0) { return null; }

                const padding = Math.max(16, Math.min(32, availableWidth * 0.05));
                const effectiveWidth = Math.max(100, availableWidth - padding * 2);
                const scale = Math.min(effectiveWidth / baseWidth, 1);
                const viewportHeight = Math.max(200, baseHeight * scale);

                return { stage, page, baseWidth, baseHeight, scale, viewportHeight, padding };
            };

            const applyScaleImmediate = () => {
                try {
                    const state = computeScale();
                    if (!state) { return; }

                    const { stage, page, baseWidth, baseHeight, scale, viewportHeight, padding } = state;
                    const root = document.documentElement;
                    root.style.setProperty('--cv-preview-scale', scale.toString());
                    root.style.setProperty('--cv-preview-stage-width', (baseWidth * scale) + 'px');
                    root.style.setProperty('--cv-preview-viewport-height', viewportHeight + 'px');
                    root.style.setProperty('--cv-preview-page-width', baseWidth + 'px');
                    root.style.setProperty('--cv-preview-page-height', baseHeight + 'px');
                    root.style.setProperty('--cv-preview-shell-padding', padding + 'px');

                    stage.style.height = viewportHeight + 'px';
                    stage.style.minHeight = viewportHeight + 'px';
                    page.style.transform = 'scale(' + scale + ')';
                } catch (error) {
                    console.error('cv-preview applyScale failed', error);
                }
            };

            window.__cvPreview.applyScale = function() {
                if (window.__cvPreview.awaitReady) {
                    window.__cvPreview.awaitReady().then(() => applyScaleImmediate());
                } else {
                    applyScaleImmediate();
                }
            };

            window.__cvPreview.reset = function() {
                const stage = document.querySelector('.cv-preview-stage');
                const page = document.querySelector('.cv-preview-page');
                const content = document.querySelector('.cv-preview-content');
                if (content) {
                    delete content.dataset.cvBaseWidth;
                    delete content.dataset.cvBaseHeight;
                }
                const root = document.documentElement;
                root.style.removeProperty('--cv-preview-scale');
                root.style.removeProperty('--cv-preview-stage-width');
                root.style.removeProperty('--cv-preview-viewport-height');
                root.style.removeProperty('--cv-preview-page-width');
                root.style.removeProperty('--cv-preview-page-height');
                root.style.removeProperty('--cv-preview-shell-padding');
                if (stage) {
                    stage.style.removeProperty('height');
                    stage.style.removeProperty('minHeight');
                }
                if (page) {
                    page.style.removeProperty('transform');
                }
                window.__cvPreview.applyScale();
            };

            window.addEventListener('resize', () => window.__cvPreview.applyScale());
            document.addEventListener('DOMContentLoaded', () => window.__cvPreview.applyScale());
        })();
    """
}
