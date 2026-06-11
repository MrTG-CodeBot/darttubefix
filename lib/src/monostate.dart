class Monostate {
  Function? onProgress;
  Function? onComplete;
  String? title;
  int? duration;

  Monostate({this.onProgress, this.onComplete, this.title, this.duration});
}
