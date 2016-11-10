part of stagexl.media;

class WebAudioApiSound extends Sound {

  AudioBuffer _audioBuffer;

  WebAudioApiSound._(AudioBuffer audioBuffer) : _audioBuffer = audioBuffer;

  //---------------------------------------------------------------------------

  static Future<Sound> load(String url, [SoundLoadOptions soundLoadOptions]) async {

    if (soundLoadOptions == null) {
      soundLoadOptions = Sound.defaultLoadOptions;
    }

    var audioUrls = soundLoadOptions.getOptimalAudioUrls(url);
    var audioContext = WebAudioApiMixer.audioContext;

    Future f = new Future.value(null);

    for (var audioUrl in audioUrls) {
      if (f == null) {
        f = HttpRequest.request(audioUrl, responseType: 'arraybuffer').then((httpRequest) {
          var audioData = httpRequest.response;
          return audioContext.decodeAudioData(audioData);
        }).then((audioBuffer) {
          return new WebAudioApiSound._(audioBuffer);
        });
      } else {
        f = f.onError((_) {
          return HttpRequest.request(audioUrl, responseType: 'arraybuffer').then((httpRequest) {
            var audioData = httpRequest.response;
            return audioContext.decodeAudioData(audioData);
          }).then((audioBuffer) {
            return new WebAudioApiSound._(audioBuffer);
          });
        });
      }
    }

    return f.onError((_) {
      if (soundLoadOptions.ignoreErrors) {
        return MockSound.load(url, soundLoadOptions);
      } else {
        throw new StateError("Failed to load audio.");
      }
    });
  }

  //---------------------------------------------------------------------------

  static Future<Sound> loadDataUrl(String dataUrl) async {

    var audioContext = WebAudioApiMixer.audioContext;
    var byteString = html.window.atob(dataUrl.split(',')[1]);
    var bytes = new Uint8List(byteString.length);

    for (int i = 0; i < byteString.length; i++) {
      bytes[i] = byteString.codeUnitAt(i);
    }

    return new Future.value().then((_) {
      try {
        var audioData = bytes.buffer;
        return audioContext.decodeAudioData(audioData);
      } catch (e) {
        throw new StateError("Failed to load audio.");
      }
    }).then((audioBuffer) {
        return new WebAudioApiSound._(audioBuffer);
    });
  }

  //---------------------------------------------------------------------------

  num get length => _audioBuffer.duration;

  SoundChannel play([
    bool loop = false, SoundTransform soundTransform]) {

    return new WebAudioApiSoundChannel(
        this, 0, this.length, loop, soundTransform);
  }

  SoundChannel playSegment(num startTime, num duration, [
    bool loop = false, SoundTransform soundTransform]) {

    return new WebAudioApiSoundChannel(
        this, startTime, duration, loop, soundTransform);
  }

}
