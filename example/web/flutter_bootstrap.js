// Simplified Flutter bootstrap script to prevent white screen issues
window.audioContext = null;

// Function to resume audio context when user interacts with the page
window.resumeAudioContext = function() {
  console.log('resumeAudioContext called');
  
  try {
    // Try to resume any suspended AudioContext instances
    if (window.audioContext && window.audioContext.state === 'suspended') {
      window.audioContext.resume().then(() => {
        console.log('AudioContext resumed successfully');
      }).catch((err) => {
        console.log('AudioContext resume failed:', err);
      });
    }
    
    // Try to resume Module_soloud AudioContext if it exists
    if (window.Module_soloud && window.Module_soloud.audioContext) {
      if (window.Module_soloud.audioContext.state === 'suspended') {
        window.Module_soloud.audioContext.resume().catch(() => {
          // Ignore errors
        });
      }
    }
  } catch (e) {
    // Ignore all errors to prevent blocking
    console.log('Audio context resume completed with some failures');
  }
};

// Handle user interaction to resume audio
function handleUserInteraction() {
  console.log('User interaction detected');
  window.resumeAudioContext();
  
  // Remove listeners after first interaction
  document.removeEventListener('click', handleUserInteraction);
  document.removeEventListener('touchstart', handleUserInteraction);
  document.removeEventListener('keydown', handleUserInteraction);
}

// Load Flutter app immediately without waiting
const scriptTag = document.createElement('script');
scriptTag.src = 'main.dart.js';
scriptTag.type = 'application/javascript';
document.body.append(scriptTag);

console.log('Flutter app loaded');

// Add event listeners after app is loaded
document.addEventListener('click', handleUserInteraction, { once: true });
document.addEventListener('touchstart', handleUserInteraction, { once: true });
document.addEventListener('keydown', handleUserInteraction, { once: true });

// Try to capture audio context after a delay, but don't block anything
setTimeout(() => {
  try {
    if (window.Module_soloud && window.Module_soloud.audioContext) {
      window.audioContext = window.Module_soloud.audioContext;
      console.log('Module_soloud AudioContext captured');
    }
  } catch (e) {
    // Ignore errors
  }
}, 2000); 