unit main;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, FileUtil, Forms, Controls, Graphics, Dialogs, ExtCtrls,
  StdCtrls, ComCtrls, Spin, Menus, Windows, LazUTF8,
  timeline_toggle, base_reader, split_lines;

const
  filter_video='所有文件(*.*)|*.*|MP4文件(*.mp4)|*.mp4|AVI文件(*.avi)|*.avi|MPG文件(*.mpg)|*.mpg|MKV文件(*.mkv)|*.mkv|*.mpg|MOV文件(*.mov)|*.mov';
  filter_audio='所有文件(*.*)|*.*|MP3文件(*.mp3)|*.mp3|WAV文件(*.wav)|*.wav|WMV文件(*.wmv)|*.wmv';

type

  { TForm_VAMix }

  TForm_VAMix = class(TForm)
    Button_CommitSubtitle: TButton;
    Button_Run: TButton;
    Button_DeltaTimeSign: TButton;
    Button_SubtitleOption: TButton;
    CheckBox_VideoMute: TCheckBox;
    FloatSpinEdit_VideoSpeed: TFloatSpinEdit;
    FloatSpinEdit_AudioSpeed: TFloatSpinEdit;
    FontDialog: TFontDialog;
    Memo_SubtitleShow: TMemo;
    Image_VideoCover: TImage;
    Image_AudioCover: TImage;
    Label_SubtitleSize: TLabel;
    Label_Subtitle: TLabel;
    Label_DeltaTime: TLabel;
    Label_DeltaTime_Sec: TLabel;
    Label_DeltaTime_MS: TLabel;
    Label_VideoPath: TLabel;
    Label_AudioPath: TLabel;
    Label_VideoSpeed: TLabel;
    Label_Video: TLabel;
    Label_Audio: TLabel;
    Label_AudioSpeed: TLabel;
    MainMenu: TMainMenu;
    MenuItem_Run: TMenuItem;
    MenuItem_ImportVideo: TMenuItem;
    MenuItem_ImportAudio: TMenuItem;
    MenuItem_Export: TMenuItem;
    MenuItem_Import: TMenuItem;
    OpenDialog: TOpenDialog;
    Panel_SubtitleColor: TPanel;
    Panel_SubtitleTimeline: TPanel;
    Panel_Subtitle: TPanel;
    Panel_Video: TPanel;
    Panel_Operation: TPanel;
    Panel_Audio: TPanel;
    Panel_VideoTimeline: TPanel;
    Panel_AudioTimeline: TPanel;
    SpinEdit_DeltaSec: TSpinEdit;
    SpinEdit_DeltaMS: TSpinEdit;
    procedure Button_CommitSubtitleClick(Sender: TObject);
    procedure Button_DeltaTimeSignClick(Sender: TObject);
    procedure Button_RunClick(Sender: TObject);
    procedure FloatSpinEdit_Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDropFiles(Sender: TObject; const FileNames: array of String);
    procedure Image_AudioCoverClick(Sender: TObject);
    procedure Image_VideoCoverClick(Sender: TObject);
    procedure Label_AudioClick(Sender: TObject);
    procedure Label_AudioPathClick(Sender: TObject);
    procedure Label_VideoClick(Sender: TObject);
    procedure Label_VideoPathClick(Sender: TObject);
    procedure MenuItem_ImportAudioClick(Sender: TObject);
    procedure MenuItem_ImportVideoClick(Sender: TObject);
    procedure MenuItem_RunClick(Sender: TObject);
    procedure Panel_AudioClick(Sender: TObject);
    procedure Panel_VideoClick(Sender: TObject);
    procedure Button_SubtitleOptionClick(Sender: TObject);
  private
    Timeline_Video:TTimelineToggle;
    Timeline_Audio:TTimelineToggle;
    Timeline_Subtitle:TTimelineToggle;
    FVideoFirst:boolean;
    FVideoDuration:int64;
    FAudioDuration:int64;
  protected
    procedure SetVideoFirst(videofirst:boolean);
  public
    property VideoFirst:boolean read FVideoFirst write SetVideoFirst;
  public
    function GetDuration(filename:string):int64;
    function GetDeltaAudio:int64;
    function GetMute:boolean;
    procedure Synchronize;
  private
    function MakeSegmentCommand(t0,t1:int64;filename:string):string;
  public
    //action
    procedure ImportVideo(filename:string);
    procedure ImportAudio(filename:string);
    procedure ImportSubtitle(filename:string);
    procedure ExportBatch(filename:string);
    procedure ExportSubtitle(filename:string);

  public
    procedure LoadSubtitle;
    procedure SaveSubtitle;
  public
    procedure VideoCursorChange(ACursorPos:longint);
    procedure AudioCursorChange(ACursorPos:longint);
    procedure SubtitleCursorChange(ACursorPos:longint);
    procedure VideoZone(ADispMin,ADispMax:longint);
    procedure AudioZone(ADispMin,ADispMax:longint);
    procedure SubtitleZone(ADispMin,ADispMax:longint);

  end;

var
  Form_VAMix: TForm_VAMix;

implementation

{$R *.lfm}

{ TForm_VAMix }

procedure TForm_VAMix.FormCreate(Sender: TObject);
begin
  Timeline_Video:=TTimelineToggle.Create(Self);
  Timeline_Audio:=TTimelineToggle.Create(Self);
  Timeline_Subtitle:=TTimelineToggle.Create(Self);
  Timeline_Video.Parent:=Panel_VideoTimeline;
  Timeline_Audio.Parent:=Panel_AudioTimeline;
  Timeline_Subtitle.Parent:=Panel_SubtitleTimeline;
  Timeline_Video.Align:=alClient;
  Timeline_Audio.Align:=alClient;
  Timeline_Subtitle.Align:=alClient;
  Timeline_Video.Editable:=false;
  Timeline_Audio.Editable:=false;
  Timeline_Subtitle.Editable:=True;
  Timeline_Video.OnUserChangeCursorPos:=@VideoCursorChange;
  Timeline_Audio.OnUserChangeCursorPos:=@AudioCursorChange;
  Timeline_Subtitle.OnUserChangeCursorPos:=@SubtitleCursorChange;
  Timeline_Video.OnUserZone:=@VideoZone;
  Timeline_Audio.OnUserZone:=@AudioZone;
  Timeline_Subtitle.OnUserZone:=@SubtitleZone;
  Timeline_Subtitle.Segments[0].Enabled:=false;
  VideoFirst:=true;
  FVideoDuration:=0;
  FAudioDuration:=0;
end;

procedure TForm_VAMix.Button_DeltaTimeSignClick(Sender: TObject);
var tmpButton:TButton;
begin
  tmpButton:=Sender as TButton;
  if tmpButton.Caption='+' then tmpButton.Caption:='-' else tmpButton.Caption:='+';
  Synchronize;
end;

procedure TForm_VAMix.Button_CommitSubtitleClick(Sender: TObject);
begin
  SaveSubtitle;
end;

procedure TForm_VAMix.Button_RunClick(Sender: TObject);
begin
  //ExportSubtitle('out.srt');
  MenuItem_RunClick(MenuItem_Run);
end;

procedure TForm_VAMix.FloatSpinEdit_Change(Sender: TObject);
begin
  Synchronize;
end;

procedure TForm_VAMix.FormDropFiles(Sender: TObject;
  const FileNames: array of String);
begin
  if length(FileNames)<>1 then begin
    ShowMessage('不能拖入超过一个文件。');
    exit;
  end;
  if FVideoFirst then ImportVideo(FileNames[0]) else ImportAudio(FileNames[0]);
  //Synchronize;
end;

procedure TForm_VAMix.Image_AudioCoverClick(Sender: TObject);
begin
  VideoFirst:=false;
end;

procedure TForm_VAMix.Image_VideoCoverClick(Sender: TObject);
begin
  VideoFirst:=true;
end;

procedure TForm_VAMix.Label_AudioClick(Sender: TObject);
begin
  VideoFirst:=false;
end;

procedure TForm_VAMix.Label_AudioPathClick(Sender: TObject);
begin
  VideoFirst:=false;
end;

procedure TForm_VAMix.Label_VideoClick(Sender: TObject);
begin
  VideoFirst:=true;
end;

procedure TForm_VAMix.Label_VideoPathClick(Sender: TObject);
begin
  VideoFirst:=true;
end;

procedure TForm_VAMix.MenuItem_ImportAudioClick(Sender: TObject);
begin
  OpenDialog.Title:='导入音频';
  OpenDialog.Filter:=filter_audio;
  OpenDialog.Options:=OpenDialog.Options+[ofFileMustExist];
  OpenDialog.Options:=OpenDialog.Options-[ofOverwritePrompt];
  if OpenDialog.Execute then ImportAudio(OpenDialog.FileName);
end;

procedure TForm_VAMix.MenuItem_ImportVideoClick(Sender: TObject);
begin
  OpenDialog.Title:='导入视频';
  OpenDialog.Filter:=filter_video;
  OpenDialog.Options:=OpenDialog.Options+[ofFileMustExist];
  OpenDialog.Options:=OpenDialog.Options-[ofOverwritePrompt];
  if OpenDialog.Execute then ImportVideo(OpenDialog.FileName);
end;

procedure TForm_VAMix.MenuItem_RunClick(Sender: TObject);
begin
  OpenDialog.Title:='导出视频';
  OpenDialog.Filter:=filter_video;
  OpenDialog.Options:=OpenDialog.Options-[ofFileMustExist];
  OpenDialog.Options:=OpenDialog.Options+[ofOverwritePrompt];
  if OpenDialog.Execute then ExportBatch(OpenDialog.FileName);
end;

procedure TForm_VAMix.Panel_AudioClick(Sender: TObject);
begin
  VideoFirst:=false;
end;

procedure TForm_VAMix.Panel_VideoClick(Sender: TObject);
begin
  VideoFirst:=true;
end;

procedure TForm_VAMix.Button_SubtitleOptionClick(Sender: TObject);
begin
  with FontDialog do if Execute then begin
    (Sender as TButton).Caption:=Font.Name+' '+IntToStr(Font.Size);
    Panel_SubtitleColor.Color:=Font.Color;
    Panel_SubtitleColor.Caption:=IntToHex(Font.Color,6);
  end;
end;

procedure TForm_VAMix.SetVideoFirst(videofirst:boolean);
begin
  if videofirst then begin
    FVideoFirst:=true;
    //Panel_Video.BevelWidth:=3;
    Panel_Video.BevelOuter:=bvLowered;
    Panel_Video.BevelColor:=clSilver;
    //Panel_Audio.BevelWidth:=1;
    Panel_Audio.BevelOuter:=bvRaised;
    Panel_Audio.BevelColor:=clDefault;
  end else begin
    FVideoFirst:=false;
    //Panel_Audio.BevelWidth:=3;
    Panel_Audio.BevelOuter:=bvLowered;
    Panel_Audio.BevelColor:=clSilver;
    //Panel_Video.BevelWidth:=1;
    Panel_Video.BevelOuter:=bvRaised;
    Panel_Video.BevelColor:=clDefault;
  end;
end;

function TForm_VAMix.GetDeltaAudio:int64;
begin
  result:=SpinEdit_DeltaSec.Value*1000+SpinEdit_DeltaMS.Value;
  if Button_DeltaTimeSign.Caption='-' then result:=-result;
end;

function TForm_VAMix.GetMute:boolean;
begin
  result:=CheckBox_VideoMute.Checked;
end;

function TForm_VAMix.GetDuration(filename:string):int64;
var t1,t2:TDateTime;
    ftmp:text;
    cmd,value:string;
    reader:TSplitLines;
begin
  result:=-1;
  DeleteFile('info.tmp');
  if FileExists('info.tmp') then begin
    ShowMessage('info.tmp文件被占用，请解除占用后手动删除。');
    exit;
  end;

  cmd:='.\ffprobe.exe -i "'+Utf8ToWinCP(filename)+'" -v quiet -show_format > "'+'info.tmp"';
  assignfile(ftmp,'get_duration.bat');
  rewrite(ftmp);
  writeln(ftmp,'setlocal');
  writeln(ftmp,cmd);
  closefile(ftmp);

  ShellExecute(0,'open','cmd.exe','/c call "get_duration.bat"',pchar(ExtractFileDir(ParamStr(0))),SW_HIDE);
  //  .\ffprobe.exe -i 1.mp4 -v quiet -show_format > 2.txt
  //  ShellExecute(0,'open','explorer',pchar('/select,"'+filename+'"'),nil,SW_NORMAL);
  t1:=Now;
  repeat
    sleep(200);
    if FileExists('info.tmp') then begin
      try
        reader:=TSplitLines.Create;
        reader.LoadFromFile('info.tmp','=');
        value:=reader.Values['duration'];
        result:=round(StrToFloat(value)*1000);
      except
        ShowMessage('读取info.tmp文件错误。');
      end;
      exit;
    end;
    t2:=Now;
  until t2-t1>1.1574e-4;
  ShowMessage('等待超过10秒，读取文件长度失败。');
end;

procedure TForm_VAMix.Synchronize;
var delta_audio:int64;
    speed_a,speed_v:double;
    newlen_a,newlen_v:int64;

begin
  if FVideoDuration*FAudioDuration=0 then exit;
  delta_audio:=GetDeltaAudio;
  speed_a:=FloatSpinEdit_AudioSpeed.Value;
  speed_v:=FloatSpinEdit_VideoSpeed.Value;

  Timeline_Video.Clear;
  Timeline_Audio.Clear;

  if delta_audio>0 then begin
    //声音晚于图像
    newlen_v:=round(FVideoDuration/speed_v);
    newlen_a:=round(FAudioDuration/speed_a)+delta_audio;
    Timeline_Video.MinPosition:=0;
    Timeline_Video.MaxPosition:=newlen_v;
    Timeline_Audio.MinPosition:=0;
    Timeline_Audio.MaxPosition:=newlen_a;
    Timeline_Audio.AddTick(delta_audio);
    Timeline_Audio.Segments[0].Enabled:=false;
  end else if delta_audio<0 then begin
    //声音早于图像
    newlen_v:=round(FVideoDuration/speed_v)-delta_audio;
    newlen_a:=round(FAudioDuration/speed_a);
    Timeline_Audio.MinPosition:=0;
    Timeline_Audio.MaxPosition:=newlen_a;
    Timeline_Video.MinPosition:=0;
    Timeline_Video.MaxPosition:=newlen_v;
    Timeline_Video.AddTick(-delta_audio);
    Timeline_Video.Segments[0].Enabled:=false;
  end else begin
      newlen_v:=round(FVideoDuration/speed_v);
      newlen_a:=round(FAudioDuration/speed_a);
      Timeline_Audio.MinPosition:=0;
      Timeline_Audio.MaxPosition:=newlen_a;
      Timeline_Video.MinPosition:=0;
      Timeline_Video.MaxPosition:=newlen_v;
  end;

  if newlen_a>newlen_v then begin
    Timeline_Video.AddTick(newlen_a);
    Timeline_Video.Segments[-1].Enabled:=false;
    Timeline_Subtitle.MaxPosition:=newlen_a;
  end else if newlen_a<newlen_v then begin
    Timeline_Audio.AddTick(newlen_v);
    Timeline_Audio.Segments[-1].Enabled:=false;
    Timeline_Subtitle.MaxPosition:=newlen_v;
  end else begin
    Timeline_Subtitle.MaxPosition:=newlen_v;//or newlen_a whatever
  end;

  Timeline_Video.ZoneToWorld;
  Timeline_Audio.ZoneToWorld;
  Timeline_Subtitle.ZoneToWorld;
  Timeline_Video.Refresh;
  Timeline_Audio.Refresh;
  Timeline_Subtitle.Refresh;

end;

procedure TForm_VAMix.ImportVideo(filename:string);
begin
  Label_VideoPath.Caption:=filename;
  Timeline_Video.Clear;
  FVideoDuration:=GetDuration(filename);
  Timeline_Video.MinPosition:=0;
  Timeline_Video.MaxPosition:=FVideoDuration;
  Timeline_Video.Refresh;
  FloatSpinEdit_VideoSpeed.Value:=1.0;
  Synchronize;
end;

procedure TForm_VAMix.ImportAudio(filename:string);
begin
  Label_AudioPath.Caption:=filename;
  Timeline_Audio.Clear;
  FAudioDuration:=GetDuration(filename);
  Timeline_Audio.MinPosition:=0;
  Timeline_Audio.MaxPosition:=FAudioDuration;
  Timeline_Audio.Refresh;
  FloatSpinEdit_AudioSpeed.Value:=1.0;
  Synchronize;
end;

procedure TForm_VAMix.ImportSubtitle(filename:string);
begin

end;

function _url(url:string):string;
begin
  result:=' -i "';
  result:=result+Utf8ToWinCP(url)+'"';
end;

function _video_speed(speed:double):string;
begin
  if speed=1 then
    result:='[0:v]copy[out_v];'
  else
    result:='[0:v]setpts='+FloatToStrF(1/speed,ffFixed,3,8)+'*PTS[out_v];';
end;

function _audio_speed(input_no:integer;speed:double):string;
var idstr:string;
begin
  idstr:=IntToStr(input_no);
  if speed=1 then
    result:='['+idstr+':a]'+'acopy[at'+idstr+'];'
  else
    result:='['+idstr+':a]'+arg_atempo(speed)+'[at'+idstr+'];';
end;

function TForm_VAMix.MakeSegmentCommand(t0,t1:int64;filename:string):string;
var stmp:string;
    vt0,vt1,at0,at1:int64;
    delta:double;
    valid_0,valid_1:boolean;
    filter:string;
begin
  delta:=GetDeltaAudio;
  if delta>0 then begin
    vt0:=round(t0*FloatSpinEdit_VideoSpeed.Value);
    vt1:=round(t1*FloatSpinEdit_VideoSpeed.Value);
    at0:=round((t0-delta)*FloatSpinEdit_AudioSpeed.Value);
    at1:=round((t1-delta)*FloatSpinEdit_AudioSpeed.Value);
  end else if delta<0 then begin
    at0:=round(t0*FloatSpinEdit_AudioSpeed.Value);
    at1:=round(t1*FloatSpinEdit_AudioSpeed.Value);
    vt0:=round((t0+delta)*FloatSpinEdit_VideoSpeed.Value);
    vt1:=round((t1+delta)*FloatSpinEdit_VideoSpeed.Value);
  end else begin
    vt0:=round(t0*FloatSpinEdit_VideoSpeed.Value);
    vt1:=round(t1*FloatSpinEdit_VideoSpeed.Value);
    at0:=round(t0*FloatSpinEdit_AudioSpeed.Value);
    at1:=round(t1*FloatSpinEdit_AudioSpeed.Value);
  end;

  stmp:='.\ffmpeg.exe -y';
  valid_0:=(vt0>=0) and (vt0<vt1) and (vt1<=FVideoDuration);
  valid_1:=(at0>=0) and (at0<at1) and (at1<=FAudioDuration);
  if valid_0 then begin
    stmp:=stmp+' -ss '+millisec_to_format(vt0) +' -to '+millisec_to_format(vt1);
    stmp:=stmp+_url(Label_VideoPath.Caption);
  end;
  if valid_1 then begin
    if not valid_0 then stmp:=stmp+' -ss 0 -to '+millisec_to_format(t1-t0)+' -f lavfi -i "color=c=0x000000"';
    stmp:=stmp+' -ss '+millisec_to_format(at0) +' -to '+millisec_to_format(at1);
    stmp:=stmp+_url(Label_AudioPath.Caption);
  end;
  if valid_0 and valid_1 then begin
    //两个输入均有效
    filter:='';
    filter:=filter+_video_speed(FloatSpinEdit_VideoSpeed.Value);
    if not GetMute then filter:=filter+_audio_speed(0,FloatSpinEdit_VideoSpeed.Value);
    filter:=filter+_audio_speed(1,FloatSpinEdit_AudioSpeed.Value);
    if not GetMute then filter:=filter+'[at0][at1]amix=inputs=2[out_a]'
    else filter:=filter+'[at1]acopy[out_a]';
    stmp:=stmp+' -filter_complex "'+filter+'"';
    stmp:=stmp+' -map "[out_v]" -map "[out_a]"';
  end else if valid_0 then begin
    //仅视频输入有效
    filter:='';
    filter:=filter+_video_speed(FloatSpinEdit_VideoSpeed.Value);
    if not GetMute then begin
      filter:=filter+_audio_speed(0,FloatSpinEdit_VideoSpeed.Value);
      filter:=filter+'[at0]acopy[out_a]';
      stmp:=stmp+' -filter_complex "'+filter+'"';
      stmp:=stmp+' -map "[out_v]" -map "[out_a]"';
    end else begin
      delete(filter,length(filter),1);//删除video filter的分号
      stmp:=stmp+' -filter_complex "'+filter+'"';
      stmp:=stmp+' -map "[out_v]"';
    end;
  end else if valid_1 then begin
    //仅音频输入有效
    filter:='';
    filter:=filter+_audio_speed(1,FloatSpinEdit_AudioSpeed.Value);
    filter:=filter+'[at1]acopy[out_a]';
    stmp:=stmp+' -filter_complex "'+filter+'"';
    stmp:=stmp+' -map 0:v -map "[out_a]"';
  end else begin
    //无有效输入
    stmp:='echo '+Utf8ToWinCP('未能输出片段');
  end;
  result:=stmp+' "'+Utf8ToWinCP(filename)+'"';
end;

//exe input_v input_a -f_c "vf;a0,a1,mix" map out
//seg1 seg2 seg3 -> out
procedure TForm_VAMix.ExportBatch(filename:string);
var cmd:TStringList;
    ticks:TDynIntArray;
    pi:integer;
    stmp:string;
begin
  ticks:=TDynIntArray.Create;
  for pi:=0 to Timeline_Video.CountTicks-1 do ticks.Append(Timeline_Video.Ticks[pi].Position);
  for pi:=0 to Timeline_Audio.CountTicks-1 do ticks.Append(Timeline_Audio.Ticks[pi].Position);
  ticks.Sort;
  ticks.Unique;

  cmd:=TStringList.Create;
  try
    cmd.Add('setlocal');
    for pi:=0 to ticks.Count-2 do
      cmd.Add(MakeSegmentCommand(ticks[pi],ticks[pi+1],'seg_'+IntToStr(pi)+'.ts'));
    stmp:='.\ffmpeg.exe -y -i "concat:';
    for pi:=0 to ticks.Count-2 do
      stmp:=stmp+'seg_'+IntToStr(pi)+'.ts|';
    delete(stmp,length(stmp),1);
    if Timeline_Subtitle.CountEnabled=0 then begin
      stmp:=stmp+'" -c copy "'+Utf8ToWinCP(filename)+'"';
    end else begin
      ExportSubtitle('out.srt');
      stmp:=stmp+'" -filter_complex "[0:a]acopy;[0:v]subtitles=out.srt" "'+Utf8ToWinCP(filename)+'"';
    end;
    cmd.Add(stmp);
    for pi:=0 to ticks.Count-2 do
      cmd.Add('del seg_'+IntToStr(pi)+'.ts');
    cmd.SaveToFile('get_batch.bat');
    ShellExecute(0,'open','cmd.exe','/c call "get_batch.bat"',pchar(ExtractFileDir(ParamStr(0))),SW_SHOW);
  finally
    cmd.Free;
  end;
  ticks.Free;
end;

procedure TForm_VAMix.ExportSubtitle(filename:string);
var index,acc:integer;
    stmp:string;
    f:text;
    tmpSeg:TTimelineToggleSegment;
begin
  stmp:='';
  acc:=1;
  for index:=0 to Timeline_Subtitle.CountSegments-1 do begin
    tmpSeg:=Timeline_Subtitle.Segments[index];
    if not tmpSeg.Enabled then continue;
    stmp:=stmp+tmpSeg.SrtText(acc);
    inc(acc);
  end;
  assignfile(f,filename);
  rewrite(f);
  writeln(f,stmp);
  closefile(f);
end;

procedure TForm_VAMix.LoadSubtitle;
var tmpSegment:TTimelineToggleSegment;
begin
  tmpSegment:=Timeline_Subtitle.CursorSegment;
  if tmpSegment=nil then exit;
  Memo_SubtitleShow.Lines.Text:=tmpSegment.Subtitle;
end;

procedure TForm_VAMix.SaveSubtitle;
var tmpSegment:TTimelineToggleSegment;
begin
  tmpSegment:=Timeline_Subtitle.CursorSegment;
  if tmpSegment=nil then exit;
  tmpSegment.Subtitle:=Memo_SubtitleShow.Lines.Text;
end;

procedure TForm_VAMix.VideoCursorChange(ACursorPos:longint);
begin
  if Timeline_Audio.ValidCursor(acursorpos) then Timeline_Audio.CursorPos:=acursorpos;
  if Timeline_Subtitle.ValidCursor(acursorpos) then Timeline_Subtitle.CursorPos:=acursorpos;
  Memo_SubtitleShow.Clear;
end;

procedure TForm_VAMix.AudioCursorChange(ACursorPos:longint);
begin
  if Timeline_Video.ValidCursor(acursorpos) then Timeline_Video.CursorPos:=acursorpos;
  if Timeline_Subtitle.ValidCursor(acursorpos) then Timeline_Subtitle.CursorPos:=acursorpos;
  Memo_SubtitleShow.Clear;
end;

procedure TForm_VAMix.SubtitleCursorChange(ACursorPos:longint);
begin
  if Timeline_Video.ValidCursor(acursorpos) then Timeline_Video.CursorPos:=acursorpos;
  if Timeline_Audio.ValidCursor(acursorpos) then Timeline_Audio.CursorPos:=acursorpos;
  LoadSubtitle;
end;

procedure TForm_VAMix.VideoZone(ADispMin,ADispMax:longint);
begin
  Timeline_Audio.Zone(ADispMin,ADispMax);
  Timeline_Subtitle.Zone(ADispMin,ADispMax);
end;

procedure TForm_VAMix.AudioZone(ADispMin,ADispMax:longint);
begin
  Timeline_Video.Zone(ADispMin,ADispMax);
  Timeline_Subtitle.Zone(ADispMin,ADispMax);
end;

procedure TForm_VAMix.SubtitleZone(ADispMin,ADispMax:longint);
begin
  Timeline_Video.Zone(ADispMin,ADispMax);
  Timeline_Audio.Zone(ADispMin,ADispMax);
end;

end.

