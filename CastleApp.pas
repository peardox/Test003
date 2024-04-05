unit CastleApp;

interface
uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs,
  FMX.Controls.Presentation,
  fmx.castlecontrol, CastleUIControls, CastleVectors,
  CastleGLUtils, CastleColors, FMX.Layouts,
  CastleViewport,
  CastleTransform,
  CastleDebugTransform,
  CastleScene;

type
  { TStageInfo }
  TStageInfo = record
    cPos: TVector3;
    cDir: TVector3;
    cUp: TVector3;
    cXlat: TVector3;
    cRot: TVector4;
    zoom: Single;
  end;

  { TCastleApp }
  TCastleApp = class(TCastleView)
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override; // TCastleUserInterface
    procedure Start; override; // TCastleView
    procedure Stop; override; // TCastleView
    procedure Resize; override; // TCastleUserInterface
    procedure RenderOverChildren; override; // TCastleUserInterface
    procedure Render; override;
    procedure BeforeRender; override;
  private
    { Private declarations }
    fStage: TCastleScene;
    fCamera: TCastleCamera;
    fCameraLight: TCastleDirectionalLight;
    fViewport: TCastleViewport;
    function CreateDirectionalLight(LightPos: TVector3): TCastleDirectionalLight;
    procedure LoadViewport;
    procedure AddModel(const AFilename: String);
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Camera: TCastleCamera read fCamera write fCamera;
    property Stage: TCastleScene read fStage write fStage;
  end;

implementation

uses
  Math,
  X3DLoad,
  CastleUriUtils,
  CastleLog,
  CastleRectangles,
  CastleProjection;

constructor TCastleApp.Create(AOwner: TComponent);
begin
  inherited;
end;

procedure TCastleApp.Start;
var
  model: TCastleScene;
begin
  inherited;
  LoadViewport;
//  AddModel('castle-data:/up.glb');
  AddModel('castle-data:/glass.obj');

end;

procedure TCastleApp.AddModel(const AFilename: String);
var
  model: TCastleScene;
begin
  if Assigned(fStage) and UriFileExists(AFilename) then
    begin
      model := TCastleScene.Create(Self);
      model.Load(AFilename);
      fStage.Add(model);
    end;
end;

procedure TCastleApp.Stop;
begin
  inherited;
end;

procedure TCastleApp.Update(const SecondsPassed: Single;
  var HandleInput: Boolean);
begin
  inherited;
end;

procedure TCastleApp.LoadViewport;
var
  bb: TDebugTransformBox;
begin
  fViewport := TCastleViewport.Create(Self);
  fViewport.FullSize := False;
  fViewport.Width := Container.UnscaledWidth;
  fViewport.Height := Container.UnscaledHeight;
  fViewport.Transparent := True;

  fStage := TCastleScene.Create(Self);

  fCamera := TCastleCamera.Create(fViewport);
  fCamera.ProjectionType := ptOrthographic;
  fCamera.Translation := Vector3(1,1,1);
  fCamera.Direction := -fCamera.Translation;

  fCamera.Orthographic.Origin := Vector2(0.5, 0.5);
  fCamera.Orthographic.Width := 2;
  fCameraLight := CreateDirectionalLight(Vector3(1,1,1));
  fCamera.Add(fCameraLight);
  fViewport.Items.Add(fCamera);
  fViewport.Items.Add(fStage);
  fViewport.Camera := fCamera;

  InsertFront(fViewport);
end;

procedure TCastleApp.BeforeRender;
begin
  inherited;
  Resize;
end;

procedure TCastleApp.Render;
begin
  inherited;
end;

procedure TCastleApp.RenderOverChildren;
begin
  inherited;
end;

procedure TCastleApp.Resize;
begin
  inherited;
  fViewport.Width := Container.UnscaledWidth;
  fViewport.Height := Container.UnscaledHeight;
end;

function TCastleApp.CreateDirectionalLight(LightPos: TVector3): TCastleDirectionalLight;
var
  Light: TCastleDirectionalLight;
begin
  Light := TCastleDirectionalLight.Create(Self);

  Light.Direction := LightPos;
  Light.Color := Vector3(1, 1, 1);
  Light.Intensity := 1;

  Result := Light;
end;


destructor TCastleApp.Destroy;
begin
  inherited;
end;

end.
