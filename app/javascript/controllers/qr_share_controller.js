import { Controller } from "@hotwired/stimulus";

export default class extends Controller {
  static targets = ["qrCode"];
  static values = { linkSlug: String, linkName: String };

  async share(event) {
    event.preventDefault();
    
    try {
      // Check if Web Share API is supported
      if (!navigator.share) {
        this.fallbackShare();
        return;
      }

      // Get the QR code SVG element
      const qrSvg = this.qrCodeTarget.querySelector('svg');
      if (!qrSvg) {
        console.error('QR code SVG not found');
        return;
      }

      // Convert SVG to canvas and then to blob
      const canvas = await this.svgToCanvas(qrSvg);
      const blob = await this.canvasToBlob(canvas);
      
      // Use link name with spaces replaced by dashes, fallback to slug if no name
      const fileName = this.linkNameValue ? 
        this.linkNameValue.replace(/\s+/g, '-').toLowerCase() : 
        this.linkSlugValue;
      
      // Create a File object from the blob
      const file = new File([blob], `qr-code-${fileName}.png`, {
        type: 'image/png'
      });

      // Share using Web Share API
      const displayName = this.linkNameValue || this.linkSlugValue;
      await navigator.share({
        title: `QR Code for ${displayName}`,
        text: `QR Code for link: ${displayName}`,
        files: [file]
      });

    } catch (error) {
      console.error('Error sharing QR code:', error);
      this.fallbackShare();
    }
  }

  async download(event) {
    event.preventDefault();
    
    try {
      // Get the QR code SVG element
      const qrSvg = this.qrCodeTarget.querySelector('svg');
      if (!qrSvg) {
        console.error('QR code SVG not found');
        return;
      }

      // Convert SVG to canvas and then to blob
      const canvas = await this.svgToCanvas(qrSvg);
      const blob = await this.canvasToBlob(canvas);
      
      // Create download link
      const url = URL.createObjectURL(blob);
      const a = document.createElement('a');
      a.href = url;
      
      // Use link name with spaces replaced by dashes, fallback to slug if no name
      const fileName = this.linkNameValue ? 
        this.linkNameValue.replace(/\s+/g, '-').toLowerCase() : 
        this.linkSlugValue;
      a.download = `qr-code-${fileName}.png`;
      
      // Trigger download
      document.body.appendChild(a);
      a.click();
      document.body.removeChild(a);
      
      // Clean up
      URL.revokeObjectURL(url);
      
      this.showNotification('QR code downloaded successfully!');

    } catch (error) {
      console.error('Error downloading QR code:', error);
      this.showNotification('Error downloading QR code');
    }
  }

  async svgToCanvas(svg) {
    // Clone the SVG to avoid modifying the original
    const svgClone = svg.cloneNode(true);
    
    // Get SVG dimensions
    const svgRect = svg.getBoundingClientRect();
    const width = svgRect.width || 200;
    const height = svgRect.height || 200;
    
    // Create canvas
    const canvas = document.createElement('canvas');
    const ctx = canvas.getContext('2d');
    
    // Set canvas size with higher resolution for better quality
    const scale = 2;
    canvas.width = width * scale;
    canvas.height = height * scale;
    ctx.scale(scale, scale);
    
    // Set white background
    ctx.fillStyle = 'white';
    ctx.fillRect(0, 0, width, height);
    
    // Convert SVG to data URL
    const svgData = new XMLSerializer().serializeToString(svgClone);
    const svgBlob = new Blob([svgData], { type: 'image/svg+xml;charset=utf-8' });
    const svgUrl = URL.createObjectURL(svgBlob);
    
    // Create image and draw to canvas
    return new Promise((resolve, reject) => {
      const img = new Image();
      img.onload = () => {
        ctx.drawImage(img, 0, 0, width, height);
        URL.revokeObjectURL(svgUrl);
        resolve(canvas);
      };
      img.onerror = reject;
      img.src = svgUrl;
    });
  }

  canvasToBlob(canvas) {
    return new Promise((resolve) => {
      canvas.toBlob(resolve, 'image/png', 0.9);
    });
  }

  fallbackShare() {
    // Fallback for browsers that don't support Web Share API
    // Copy current page URL to clipboard
    const currentUrl = window.location.href;
    
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(currentUrl).then(() => {
        this.showNotification('Link copied to clipboard!');
      }).catch(() => {
        this.showNotification('Unable to copy link');
      });
    } else {
      // Even older fallback
      this.showNotification('Web Share not supported on this browser');
    }
  }

  showNotification(message) {
    // Create notification using the existing stimulus-components/notification system
    const notification = document.createElement('div');
    notification.setAttribute('data-controller', 'notification');
    notification.setAttribute('data-notification-delay-value', '4000');
    notification.className = 'fixed right-4 top-28 bg-white shadow-2xl rounded-lg p-4 w-11/12 sm:max-w-sm transition duration-300 flex items-center z-20 ring-1 ring-gray-200';
    notification.setAttribute('data-transition-enter-from', 'opacity-0 translate-y-6');
    notification.setAttribute('data-transition-enter-to', 'opacity-100 translate-y-0');
    notification.setAttribute('data-transition-leave-from', 'opacity-100 translate-y-0');
    notification.setAttribute('data-transition-leave-to', 'opacity-0 translate-y-6');
    notification.setAttribute('data-notification-target', 'container');
    
    notification.innerHTML = `
      <div class="mr-3 flex-shrink-0">
        <svg xmlns="http://www.w3.org/2000/svg" fill="none" viewBox="0 0 24 24" stroke-width="1.5" stroke="currentColor" class="w-5 h-5 text-primary-600">
          <path stroke-linecap="round" stroke-linejoin="round" d="M9 12.75L11.25 15 15 9.75M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
        </svg>
      </div>
      <div>
        <p class="text-sm font-medium text-gray-800">${message}</p>
      </div>
      <div class="ml-auto pl-3">
        <button 
          data-action="notification#hide"
          class="inline-flex text-gray-400 hover:text-gray-500 focus:outline-none"
        >
          <svg class="h-5 w-5" fill="none" viewBox="0 0 24 24" stroke="currentColor">
            <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M6 18L18 6M6 6l12 12" />
          </svg>
        </button>
      </div>
    `;
    
    document.body.appendChild(notification);
  }
} 