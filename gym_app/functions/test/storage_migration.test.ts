import {
  isLegacyStorageUrl,
  storagePathFromResource,
} from '../src/storage_migration';

describe('storage migration helpers', () => {
  test('converts Firebase download URLs to object paths', () => {
    const url =
      'https://firebasestorage.googleapis.com/v0/b/gymbt-4ef87.appspot.com/o/' +
      'users%2Fuser-1%2Fprofile.jpg?alt=media&token=old-token';

    expect(storagePathFromResource(url)).toBe('users/user-1/profile.jpg');
    expect(isLegacyStorageUrl(url)).toBe(true);
  });

  test('converts gs URLs and rejects external URLs', () => {
    expect(storagePathFromResource('gs://bucket/chat/audio.m4a')).toBe(
      'chat/audio.m4a',
    );
    expect(storagePathFromResource('https://example.com/file.jpg')).toBeNull();
    expect(isLegacyStorageUrl('https://example.com/file.jpg')).toBe(true);
  });

  test('does not return traversal paths', () => {
    expect(
      storagePathFromResource(
        'https://firebasestorage.googleapis.com/v0/b/b/o/%2E%2E%2Fsecret',
      ),
    ).toBeNull();
  });
});
