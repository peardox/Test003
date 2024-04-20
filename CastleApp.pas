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
  CastleRectangles,
  CastleScene;

type
  { TCastleApp }
  TCastleApp = class(TCastleView)
    procedure Update(const SecondsPassed: Single; var HandleInput: Boolean); override; // TCastleUserInterface
    procedure Start; override; // TCastleView
    procedure Stop; override; // TCastleView
    procedure Resize; override; // TCastleUserInterface
    procedure RenderOverChildren; override; // TCastleUserInterface
    procedure Render; override;
    procedure BeforeRender; override;
    { Override everything we might want to actually use }
  private
    { Private declarations }
    fStage: TCastleScene; // A Holding Scene
    fCamera: TCastleCamera; // The camera
    fCameraLight: TCastleDirectionalLight; // A light
    fViewport: TCastleViewport; // The VP
    function CreateDirectionalLight(LightPos: TVector3): TCastleDirectionalLight;
    procedure MakeViewport;
    procedure AddModel(const AFilename: String);
    procedure DrawEnvelope;
  public
    { Public declarations }
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;
    property Camera: TCastleCamera read fCamera write fCamera;
    property Stage: TCastleScene read fStage write fStage;
  end;

  { TFloatRectangleHelper }
  TFloatRectangleHelper = record helper for TFloatRectangle
  public
    function Remap(const InRange, OutRange: TFloatRectangle): TFloatRectangle;
  end;

  { TCastleViewportHelper }
  TCastleViewportHelper = class helper for TCastleViewport
  public
    function GetEnvelope(const AScene: TCastleScene): TFloatRectangle;
  end;

implementation

uses
  Math,
  X3DLoad,
  CastleUtils,
  CastleUriUtils,
  CastleBoxes,
  CastleLog,
  CastleProjection;

constructor TCastleApp.Create(AOwner: TComponent);
{ Simplified creation from FormCreate that sets up parent params
  Note that it defaults to Client layout so if you don't want
  it being full app then create the parent TCastleControl with
  an owning component e.g. a TLayout
}
var
  OwningCC: TCastleControl;
begin
  inherited;
  if AOwner is TCastleControl then
    begin
      OwningCC := AOwner as TCastleControl;
      OwningCC.Align := TAlignLayout.Client;
      OwningCC.Container.View := Self;
      if OwningCC.Owner is TFmxObject then
        begin
          OwningCC.Parent := OwningCC.Owner as TFmxObject;
        end
      else
        Raise Exception.Create('CastleControl must be owned by a TFmxObject');
    end
  else
    Raise Exception.Create('Owner must be a TCastleControl');
end;

procedure TCastleApp.Start;
begin
  inherited;
  MakeViewport; // Make the VP
  AddModel('castle-data:/up.glb'); // Add a test model to the holding scene
                                   // created by MakeViewport
end;

procedure TCastleApp.AddModel(const AFilename: String);
{ Adds a model to the holding scene }
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

procedure TCastleApp.MakeViewport;
begin
  fViewport := TCastleViewport.Create(Self);
  fViewport.FullSize := False;
  fViewport.Width := Container.UnscaledWidth;
  fViewport.Height := Container.UnscaledHeight;
  fViewport.Transparent := True;
  { Setup basic VP }

  fStage := TCastleScene.Create(Self);
  { Create a holding scene }

  fCamera := TCastleCamera.Create(fViewport);
  fCamera.ProjectionType := ptOrthographic;
  fCamera.Translation := Vector3(1,1,1);
  fCamera.Direction := -fCamera.Translation;
  fCamera.Orthographic.Origin := Vector2(0.5, 0.5);
  fCamera.Orthographic.Width := 2;
  { Setup Camera }

  fCameraLight := CreateDirectionalLight(Vector3(0,0,1));
  fCamera.Add(fCameraLight);
  { Create light and add it to Camera }

  fViewport.Items.Add(fCamera);
  fViewport.Items.Add(fStage);
  { Add to VP }

  fViewport.Camera := fCamera;
  { Set VP camera }

  InsertFront(fViewport);
  { Make it active }
end;

procedure TCastleApp.BeforeRender;
begin
  inherited;
end;

procedure TCastleApp.Render;
begin
  inherited;
end;

procedure TCastleApp.RenderOverChildren;
begin
  inherited;
  DrawEnvelope;
  { Try drawing the envelope }
end;

procedure TCastleApp.Resize;
{ Handle resiz3wee }
begin
  inherited;
  fViewport.Width := Container.UnscaledWidth;
  fViewport.Height := Container.UnscaledHeight;
end;

function TCastleApp.CreateDirectionalLight(LightPos: TVector3): TCastleDirectionalLight;
{ Just create a light for the scene }
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

procedure TCastleApp.DrawEnvelope;
var
  cr: TFloatRectangle;
begin
  if Assigned(fStage) then
    begin
      cr := fViewport.GetEnvelope(fStage);
      if not cr.IsEmpty then
        begin
//          WriteLnLog(cr.ToString);
          cr := cr.Remap(fCamera.Orthographic.EffectiveRect, EffectiveRect);
          DrawRectangleOutline(cr, White);
        end;
    end;
end;

{ TCastleViewportHelper }

function TCastleViewportHelper.GetEnvelope(const AScene: TCastleScene): TFloatRectangle;
var
  OutputMatrix:TMatrix4;
  OutputPoint3D: TVector3;
  i: Integer;
  rMin, rMax: TVector2;
  Corners: TBoxCorners;
begin
  Result := TFloatRectangle.Empty;
  rMin := Vector2(Infinity, Infinity);
  rMax := Vector2(-Infinity, -Infinity);
  { Initialise Extent min+max with max values }

  if ((EffectiveWidth > 0) and (EffectiveHeight > 0) and Assigned(AScene) and not AScene.LocalBoundingBox.IsEmptyOrZero) then
	begin
	  AScene.LocalBoundingBox.Corners(Corners);
    { Get BB Corners }
    OutputMatrix := Camera.ProjectionMatrix * Camera.Matrix * AScene.WorldTransform;
	  for i := Low(Corners) to High(Corners) do
		begin
		  OutputPoint3D := OutputMatrix.MultPoint(Corners[i]);
      { Convert 3D vertex to 2D }
		  if OutputPoint3D.X < rMin.X then
		  	rMin.X := OutputPoint3D.X;
		  if OutputPoint3D.Y < rMin.Y then
	  		rMin.Y := OutputPoint3D.Y;
		  if OutputPoint3D.X > rMax.X then
  			rMax.X := OutputPoint3D.X;
		  if OutputPoint3D.Y > rMax.Y then
			  rMax.Y := OutputPoint3D.Y;
      { Extract Min + Max }
		end;

    Result.Left := rMin.X;
    result.Bottom := rMin.Y;
	  Result.Width := (rMax.X - rMin.X);
	  Result.Height := (rMax.Y - rMin.Y);
    { Fill in result }
	end;
end;

{ TFloatRectangleHelper }

function TFloatRectangleHelper.Remap(const InRange, OutRange: TFloatRectangle): TFloatRectangle;
begin
  { Wrong mapping }
  Result.Left := MapRange(Left, InRange.Left, InRange.Left + InRange.Width, OutRange.Left, OutRange.Left + OutRange.Width);
  Result.Bottom := MapRange(Bottom, InRange.Bottom, InRange.Bottom + InRange.Height, OutRange.Bottom, OutRange.Bottom + OutRange.Height);
  Result.Width := MapRange(Width, InRange.Left, InRange.Left + InRange.Width, OutRange.Left, OutRange.Left + OutRange.Width);
  Result.Height := MapRange(Height, InRange.Bottom, InRange.Bottom + InRange.Height, OutRange.Bottom, OutRange.Bottom + OutRange.Height);
end;


end.
