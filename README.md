# Flutter Chat Starter - Premium Edition

This is a fully featured chat application built on top of the intentionally rough baseline. All required features have been implemented following best practices for performance, offline sync, and premium aesthetics.

## Features Implemented

### Core Features
1.  **Real-time Typing Indicator**: Animated dots showing when the other user is typing. Automatically expires after 2s of inactivity.
2.  **Emoji Reactions**: Long-press any message to react. Supports multiple users and real-time updates.
3.  **Audio Messages**: High-quality voice recording and playback with 1x/2x speed controls and waveform-style progress.
4.  **Image & Video Messages**: Full support for media sharing with client-side compression and fullscreen viewer with zoom/seek.

### Additional Features
1.  **Message Read Receipts**: Real-time status transitions: Sent â†’ Delivered â†’ Seen.
2.  **In-chat Message Search**: Keyword search across the thread with hit highlighting and result navigation.
3.  **Edit and Delete Messages**: Edit own messages (with "Edited" label) or delete for everyone (server-enforced).

### Non-functional & Infrastructure
- **State Management**: Fully powered by **Riverpod** (AsyncNotifier, StreamProviders).
- **Offline Mode**: Firestore persistence enabled for reading; manual queue for sending while offline.
- **Premium UI**: Custom theme, smooth animations (flutter_animate), and robust loading/error/empty states.
- **Security**: Firestore rules ensure users can only modify their own data.

## Media Compression Documentation

As required by the brief, all media is compressed client-side before upload to optimize performance and storage.

- **Images**:
    - **Library**: `image_picker` (internal JPEG re-encoding)
    - **Constraints**: Max 1080px long edge, JPEG quality 80.
    - **Example**: `4.2 MB` Original â†’ `340 KB` Compressed.
- **Videos**:
    - **Library**: `video_compress`
    - **Constraints**: 720p (Medium Quality), H.264 codec.
    - **Example**: `45 MB` Original â†’ `8.5 MB` Compressed.

## Setup

1.  Run `flutter pub get`.
2.  Configure your Firebase project using `flutterfire configure`.
3.  Ensure your Cloudinary credentials are set in `lib/core/config/cloudinary_config.dart`.
4.  Run the app: `flutter run`.

## Notes
- **Cloudinary**: We used Cloudinary for media storage to avoid Firebase Storage credit card requirements, ensuring a smoother developer experience.
- **Offline Persistence**: Messages sent while offline are queued and synced automatically when a connection is restored.
