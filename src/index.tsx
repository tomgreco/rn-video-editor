import { NativeModules, Platform } from 'react-native';

const LINKING_ERROR =
  `The package 'rn-video-editor' doesn't seem to be linked. Make sure: \n\n` +
  Platform.select({ ios: "- You have run 'pod install'\n", default: '' }) +
  '- You rebuilt the app after installing the package\n' +
  '- You are not using Expo managed workflow\n';

const RnVideoEditor = NativeModules.RnVideoEditor
  ? NativeModules.RnVideoEditor
  : new Proxy(
      {},
      {
        get() {
          throw new Error(LINKING_ERROR);
        },
      }
    );

export function mergeVideos(
  filePaths: string[],
  failureCallback: (results: string) => void,
  successCallback: (results: string, file: string) => void): void {
  return RnVideoEditor.mergeVideos(filePaths, failureCallback, successCallback);
}
