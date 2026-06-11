class DarttubefixError implements Exception {
  final String message;
  DarttubefixError(this.message);

  @override
  String toString() => message;
}

class MaxRetriesExceeded extends DarttubefixError {
  MaxRetriesExceeded() : super("Maximum number of retries exceeded");
}

class HTMLParseError extends DarttubefixError {
  HTMLParseError(super.message);
}

class ExtractError extends DarttubefixError {
  ExtractError(super.message);
}

class SABRError extends DarttubefixError {
  final String msg;
  SABRError(this.msg) : super(msg);
}

class RegexMatchError extends ExtractError {
  final String caller;
  final String pattern;
  RegexMatchError(this.caller, this.pattern)
      : super("$caller: could not find match for $pattern");
}

class InterpretationError extends DarttubefixError {
  final String jsUrl;
  final dynamic reason;
  InterpretationError(this.jsUrl, [this.reason])
      : super("Error interpreting player js: $jsUrl" + (reason != null ? " reason: $reason" : ""));
}

class VideoUnavailable extends DarttubefixError {
  final String videoId;
  VideoUnavailable(this.videoId, [String? message])
      : super(message ?? "$videoId is unavailable");
}

class VideoRemovedByYouTubeForViolatingTOS extends VideoUnavailable {
  final String reason;
  VideoRemovedByYouTubeForViolatingTOS(String videoId, [String? reason])
      : reason = reason ?? "This video has been removed for violating YouTube's Community Guidelines.",
        super(videoId, "$videoId ${reason ?? "This video has been removed for violating YouTube's Community Guidelines."}");
}

class LiveStreamEnded extends VideoUnavailable {
  final String reason;
  LiveStreamEnded(String videoId, [String? reason])
      : reason = reason ?? "This live event has ended.",
        super(videoId, "$videoId ${reason ?? "This live event has ended."}");
}

class VideoBlockedByCopyright extends VideoUnavailable {
  final String reason;
  VideoBlockedByCopyright(String videoId, [String? reason])
      : reason = reason ?? "This video contains content that is blocked in your country on copyright grounds.",
        super(videoId, "$videoId ${reason ?? "This video contains content that is blocked in your country on copyright grounds."}");
}

class VideoRemovedByUploader extends VideoUnavailable {
  final String reason;
  VideoRemovedByUploader(String videoId, [String? reason])
      : reason = reason ?? "This video has been removed by the uploader",
        super(videoId, "$videoId ${reason ?? "This video has been removed by the uploader"}");
}

class AccountTerminated extends VideoUnavailable {
  final String reason;
  AccountTerminated(String videoId, [String? reason])
      : reason = reason ?? "This video is no longer available because the YouTube account associated with this video has been terminated.",
        super(videoId, "$videoId ${reason ?? "This video is no longer available because the YouTube account associated with this video has been terminated."}");
}

class VideoPrivate extends VideoUnavailable {
  VideoPrivate(String videoId) : super(videoId, "$videoId is a private video");
}

class MembersOnly extends VideoUnavailable {
  MembersOnly(String videoId) : super(videoId, "$videoId is a members-only video");
}

class VideoRegionBlocked extends VideoUnavailable {
  VideoRegionBlocked(String videoId) : super(videoId, "$videoId is not available in your region");
}

class BotDetection extends VideoUnavailable {
  BotDetection(String videoId)
      : super(videoId, "$videoId This request was detected as a bot. See details at https://pytubefix.readthedocs.io/en/latest/user/po_token.html");
}

class PoTokenRequired extends VideoUnavailable {
  final String clientName;
  PoTokenRequired(String videoId, this.clientName)
      : super(videoId, "$videoId The $clientName client requires PoToken to obtain functional streams");
}

class LoginRequired extends VideoUnavailable {
  final String reason;
  LoginRequired(String videoId, this.reason)
      : super(videoId, "$videoId requires login to view, YouTube reason: $reason");
}

class RecordingUnavailable extends VideoUnavailable {
  RecordingUnavailable(String videoId)
      : super(videoId, "$videoId does not have a live stream recording available");
}

class LiveStreamError extends VideoUnavailable {
  LiveStreamError(String videoId)
      : super(videoId, "$videoId is streaming live and cannot be loaded");
}

class LiveStreamOffline extends VideoUnavailable {
  final String reason;
  LiveStreamOffline(String videoId, this.reason)
      : super(videoId, "$videoId $reason");
}

class AgeRestrictedError extends VideoUnavailable {
  AgeRestrictedError(String videoId)
      : super(videoId, "$videoId is age restricted, and can't be accessed without logging in.");
}

class AgeCheckRequiredError extends VideoUnavailable {
  AgeCheckRequiredError(String videoId)
      : super(videoId, "$videoId has age restrictions and cannot be accessed without confirmation.");
}

class AgeCheckRequiredAccountError extends VideoUnavailable {
  AgeCheckRequiredAccountError(String videoId)
      : super(videoId, "$videoId may be inappropriate for some users. Sign in to your primary account to confirm your age.");
}

class InnerTubeResponseError extends VideoUnavailable {
  final String client;
  InnerTubeResponseError(String videoId, this.client)
      : super(videoId, "$videoId : $client client did not receive a response from YouTube");
}

class UnknownVideoError extends VideoUnavailable {
  final String? status;
  final String? reason;
  final String? developerMessage;

  UnknownVideoError(String videoId, {this.status, this.reason, this.developerMessage})
      : super(videoId, "$videoId has an unknown error [Status: $status] [Reason: $reason] [DeveloperMessage: $developerMessage]");
}
