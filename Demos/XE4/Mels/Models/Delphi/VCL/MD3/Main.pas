// *************************************************************************************************
// * ==> Main -------------------------------------------------------------------------------------*
// *************************************************************************************************
// * MIT License - The Mels Library, a free and easy-to-use 3D Models library                      *
// *                                                                                               *
// * Permission is hereby granted, free of charge, to any person obtaining a copy of this software *
// * and associated documentation files (the "Software"), to deal in the Software without          *
// * restriction, including without limitation the rights to use, copy, modify, merge, publish,    *
// * distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the *
// * Software is furnished to do so, subject to the following conditions:                          *
// *                                                                                               *
// * The above copyright notice and this permission notice shall be included in all copies or      *
// * substantial portions of the Software.                                                         *
// *                                                                                               *
// * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING *
// * BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND    *
// * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM,  *
// * DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING      *
// * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. *
// *************************************************************************************************

{**
 @abstract(@name contains the MD3 demo main form.)
 @author(Jean-Milost Reymond)
 @created(2015 - 2016, this file is part of the Mels library)
}
unit Main;

interface

uses System.Classes,
     System.UITypes,
     System.SysUtils,
     System.Variants,
     System.Generics.Collections,
     Vcl.Graphics,
     Vcl.Controls,
     Vcl.ExtCtrls,
     Vcl.Forms,
     Vcl.Dialogs,
     Winapi.Messages,
     Winapi.Windows,
     UTQRSmartPointer,
     UTQR3D,
     UTQRGraphics,
     UTQRGeometry,
     UTQRCollision,
     UTQRModel,
     UTQRMD3,
     UTQRShaderOpenGL,
     UTQROpenGLHelper,
     UTOptions,
     {$IF CompilerVersion <= 25}
         // for compiler until XE4 (not sure until which version), the DelphiGL library is required,
         // because the OpenGL include provided by Embarcadero is incomplete
         XE7.OpenGL,
         XE7.OpenGLext;
     {$ELSE}
         Winapi.OpenGL,
         Winapi.OpenGLext;
     {$ENDIF}

type
    {**
     MD3 demo main form
    }
    TMainForm = class(TForm)
        published
            paRendering: TPanel;

            procedure FormCreate(pSender: TObject);
            procedure FormResize(pSender: TObject);
            procedure FormKeyPress(pSender: TObject; var Key: Char);
            procedure FormPaint(pSender: TObject);

        private type
            {**
             Frame structure, contains the local model cache
            }
            IFrame = class
                private
                    m_pMesh:     TQRMesh;
                    m_pAABBTree: TQRAABBTree;

                public
                    {**
                     Constructor
                     @param(useCollisions - if @true, collisions detection is enabled)
                    }
                    constructor Create(useCollisions: Boolean); virtual;

                    {**
                     Destructor
                    }
                    destructor Destroy; override;
            end;

            IFrames = TObjectDictionary<NativeUInt, IFrame>;

        private
            m_pFrames:                  IFrames;
            m_hDC:                      THandle;
            m_hRC:                      THandle;
            m_pMD3:                     TQRMD3Model;
            m_pColorShader:             TQRShaderOpenGL;
            m_pTextureShader:           TQRShaderOpenGL;
            m_Textures:                 TQRTextures;
            m_ProjectionMatrix:         TQRMatrix4x4;
            m_ViewMatrix:               TQRMatrix4x4;
            m_ModelMatrix:              TQRMatrix4x4;
            m_InterpolationFactor:      Double;
            m_PreviousTime:             NativeUInt;
            m_FrameIndex:               NativeUInt;
            m_FPS:                      NativeUInt;
            m_FullScreen:               Boolean;
            m_UseShader:                Boolean;
            m_UsePreCalculatedLighting: Boolean;
            m_Collisions:               Boolean;

            {**
             Configures OpenGL
            }
            procedure ConfigOpenGL;

            {**
             Builds shader
             @param(pVertexPrg Stream containing vertex program)
             @param(pFragmentPrg Stream containing fragment program)
             @param(pShader Shader to populate)
             @return(@true on success, otherwise @false)
            }
            function BuildShader(pVertexPrg, pFragmentPrg: TStream;
                                                  pShader: TQRShaderOpenGL): Boolean;

            {**
             Loads MD3 model
             @param(useShader If @true, shader will be used)
             @return(@true on success, otherwise @false)
            }
            function LoadModel(useShader: Boolean): Boolean;

            {**
             Gets frame from local cache
             @param(index Frame index)
             @param(pModel Model for which next frame should be get)
             @param(useCollision If @true, collisions are used)
             @return(Frame)
            }
            function GetFrame(index: NativeUInt; pModel: TQRMD3Model; useCollision: Boolean): IFrame;

            {**
             Detects collision with mouse pointer and draws the polygons in collision
             @param(modelMatrix Model matrix)
             @param(pAABBTree Aligned-axis bounding box tree)
             @param(useShader Whether or not shader are used to draw model)
             @param(collisions Whether or not collisions are visible)
            }
            procedure DetectAndDrawCollisions(const modelMatrix: TQRMatrix4x4;
                                                const pAABBTree: TQRAABBTree;
                                          useShader, collisions: Boolean);

            {**
             Prepres the shader to draw the model
             @param(pShader Shader to prepare)
             @param(textures Textures belonging to model)
            }
            procedure PrepareShaderToDrawModel(pShader: TQRShaderOpenGL; const textures: TQRTextures);

            {**
             Loads model texture
             @param(pTexture Texture info)
             @return(@true on success, otherwise @false)
            }
            function LoadTexture(pTexture: TQRTexture): Boolean;

            {**
             Draws model
             @param(pGroup Group at which model belongs)
             @param(pModel Model to draw)
             @param(textures Textures belonging to model, in the order where they should be combined)
             @param(matrix Model matrix)
             @param(index Model mesh index$9
             @param(nextIndex Model mesh index to interpolate with)
             @param(interpolationFactor Interpolation factor)
             @param(useShader Whether or not shader are used to draw model)
             @param(collisions Whether or not collisions are visible)
            }
            procedure DrawModel(pModel: TQRMD3Model;
                        const textures: TQRTextures;
                          const matrix: TQRMatrix4x4;
                      index, nextIndex: NativeInt;
                   interpolationFactor: Double;
                 useShader, collisions: Boolean);

        protected
            {**
             Called when application do nothing
             @param(pSender Event sender)
             @param(done @bold([in, out]) If @true, loop will be considered as completed)
            }
            procedure OnIdle(pSender: TObject; var done: Boolean); virtual;

            {**
             Renders (i.e. prepares and draws) scene
            }
            procedure RenderGLScene; virtual;

            {**
             Draws scene
             @param(elapsedTime Elapsed time since last draw)
            }
            procedure Draw(const elapsedTime: Double); virtual;

        public
            {**
             Constructor
             @param(pOwner Form owner)
            }
            constructor Create(pOwner: TComponent); override;

            {**
             Destructor
            }
            destructor Destroy; override;
    end;

var
    MainForm: TMainForm;

implementation
//--------------------------------------------------------------------------------------------------
// Resources
//--------------------------------------------------------------------------------------------------
{$R *.dfm}
//--------------------------------------------------------------------------------------------------
// TMainForm.IFrame
//--------------------------------------------------------------------------------------------------
constructor TMainForm.IFrame.Create(useCollisions: Boolean);
begin
    inherited Create;

    if (useCollisions) then
        m_pAABBTree := TQRAABBTree.Create
    else
        m_pAABBTree := nil;
end;
//--------------------------------------------------------------------------------------------------
destructor TMainForm.IFrame.Destroy;
begin
    m_pAABBTree.Free;

    inherited Destroy;
end;
//--------------------------------------------------------------------------------------------------
// TMainForm
//--------------------------------------------------------------------------------------------------
constructor TMainForm.Create(pOwner: TComponent);
begin
    inherited Create(pOwner);

    m_pFrames                  := IFrames.Create([doOwnsValues]);
    m_hDC                      := 0;
    m_hRC                      := 0;
    m_pMD3                     := nil;
    m_pColorShader             := nil;
    m_pTextureShader           := nil;
    m_InterpolationFactor      := 0.0;
    m_PreviousTime             := GetTickCount;
    m_FrameIndex               := 0;
    m_FPS                      := 12;
    m_FullScreen               := False;
    m_UseShader                := True;
    m_UsePreCalculatedLighting := True;
    m_Collisions               := True;
end;
//--------------------------------------------------------------------------------------------------
destructor TMainForm.Destroy;
var
    i: NativeUInt;
begin
    // delete textures
    if (Length(m_Textures) > 0) then
        for i := 0 to Length(m_Textures) - 1 do
            m_Textures[i].Free;

    // delete cached frames, if any
    m_pFrames.Free;

    // delete color shader
    m_pColorShader.Free;

    // delete texture shader
    m_pTextureShader.Free;

    // delete MD3 model
    m_pMD3.Free;

    // shutdown OpenGL
    TQROpenGLHelper.DisableOpenGL(Handle, m_hDC, m_hRC);

    inherited Destroy;
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.FormCreate(pSender: TObject);
var
    pOptions: IQRSmartPointer<TOptions>;
begin
    // show options
    pOptions                      := TQRSmartPointer<TOptions>.Create(TOptions.Create(Self));
    pOptions.ckFullScreen.Checked := m_FullScreen;
    pOptions.ckUseShader.Checked  := m_UseShader;
    pOptions.ckCollisions.Checked := m_Collisions;
    pOptions.ShowModal();

    // apply options
    m_FullScreen := pOptions.ckFullScreen.Checked;
    m_UseShader  := pOptions.ckUseShader.Checked;
    m_Collisions := pOptions.ckCollisions.Checked;

    // do show model in full screen?
    if (m_FullScreen) then
    begin
        BorderStyle := bsNone;
        WindowState := wsMaximized;
        ShowCursor(m_Collisions);
    end
    else
    begin
        BorderStyle := bsSizeable;
        WindowState := wsNormal;
        ShowCursor(True);
    end;

    BringToFront;

    // select correct cursor to use
    if (m_Collisions) then
        paRendering.Cursor := crCross
    else
        paRendering.Cursor := crDefault;

    // initialize OpenGL
    if (not TQROpenGLHelper.EnableOpenGL(paRendering.Handle, m_hDC, m_hRC)) then
    begin
        MessageDlg('OpenGL could not be initialized.\r\n\r\nApplication will close.',
                   mtError,
                   [mbOK],
                   0);

        Application.Terminate;
        Exit;
    end;

    // do use shader?
    if (m_UseShader) then
        InitOpenGLext;

    // configure OpenGL
    ConfigOpenGL;

    // load MD3 model
    if (not LoadModel(m_UseShader)) then
    begin
        MessageDlg('Failed to load MD3 model.\r\n\r\nApplication will close.',
                   mtError,
                   [mbOK],
                   0);

        Application.Terminate;
        Exit;
    end;

    // from now, OpenGL will draw scene every time the thread do nothing else
    Application.OnIdle := OnIdle;
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.FormResize(pSender: TObject);
var
    position, direction, up: TQRVector3D;
begin
    // create projection matrix (will not be modified while execution)
    m_ProjectionMatrix := TQROpenGLHelper.GetProjection(45.0,
                                                        ClientWidth,
                                                        ClientHeight,
                                                        1.0,
                                                        200.0);

    position  := Default(TQRVector3D);
    direction := TQRVector3D.Create(0.0, 0.0, 1.0);
    up        := TQRVector3D.Create(0.0, 1.0, 0.0);

    // create view matrix (will not be modified while execution)
    m_ViewMatrix := TQROpenGLHelper.LookAtLH(position, direction, up);

    TQROpenGLHelper.CreateViewport(ClientWidth, ClientHeight, not m_UseShader);
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.FormKeyPress(pSender: TObject; var key: Char);
begin
    case (Integer(key)) of
        VK_ESCAPE: Application.Terminate;
    end;
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.FormPaint(pSender: TObject);
begin
    RenderGLScene;
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.ConfigOpenGL;
begin
    // configure OpenGL
    glEnable(GL_DEPTH_TEST);
    glEnable(GL_CULL_FACE);
    glCullFace(GL_FRONT);
    glEnable(GL_TEXTURE_2D);
end;
//--------------------------------------------------------------------------------------------------
function TMainForm.BuildShader(pVertexPrg, pFragmentPrg: TStream;
                                                pShader: TQRShaderOpenGL): Boolean;
begin
    // load and compile shader
    pShader.CreateProgram;
    pShader.AttachFile(pVertexPrg,   EQR_ST_Vertex);
    pShader.AttachFile(pFragmentPrg, EQR_ST_Fragment);

    // try to link shader
    Result := pShader.Link(False);
end;
//--------------------------------------------------------------------------------------------------
function TMainForm.LoadModel(useShader: Boolean): Boolean;
var
    hPackageInstance:                                  THandle;
    pVertexPrg, pFragmentPrg, pModelStream, pNTStream: TResourceStream;
    pColor:                                            TQRColor;
    pTexture:                                          TQRTexture;
begin
    // delete cached frames, if any
    m_pFrames.Clear;

    // get module instance at which this form belongs
    hPackageInstance := FindClassHInstance(TMainForm);

    // found it?
    if (hPackageInstance = 0) then
    begin
        Result := False;
        Exit;
    end;

    // do use shader?
    if (useShader) then
    begin
        pVertexPrg   := nil;
        pFragmentPrg := nil;

        // color shader still not loaded?
        if (not Assigned(m_pColorShader)) then
            try
                // found resource containing the vertex shader program to load?
                if (FindResource(hPackageInstance, PChar('ID_COLOR_VERTEX_SHADER'), RT_RCDATA) <> 0)
                then
                    pVertexPrg := TResourceStream.Create(hPackageInstance,
                                                         PChar('ID_COLOR_VERTEX_SHADER'),
                                                         RT_RCDATA);

                // found resource containing the fragment shader program to load?
                if (FindResource(hPackageInstance, PChar('ID_COLOR_FRAGMENT_SHADER'), RT_RCDATA) <> 0)
                then
                    pFragmentPrg := TResourceStream.Create(hPackageInstance,
                                                         PChar('ID_COLOR_FRAGMENT_SHADER'),
                                                         RT_RCDATA);

                // create color shader
                m_pColorShader := TQRShaderOpenGL.Create;

                // try to build shader
                if (not BuildShader(pVertexPrg, pFragmentPrg, m_pColorShader)) then
                begin
                    Result := False;
                    Exit;
                end;
            finally
                // delete resource streams, if needed
                pVertexPrg.Free;
                pFragmentPrg.Free;
            end;

        pVertexPrg   := nil;
        pFragmentPrg := nil;

        // texture shader still not loaded?
        if (not Assigned(m_pTextureShader)) then
            try
                // found resource containing the vertex shader program to load?
                if (FindResource(hPackageInstance, PChar('ID_TEXTURE_VERTEX_SHADER'), RT_RCDATA) <> 0)
                then
                    pVertexPrg := TResourceStream.Create(hPackageInstance,
                                                         PChar('ID_TEXTURE_VERTEX_SHADER'),
                                                         RT_RCDATA);

                // found resource containing the fragment shader program to load?
                if (FindResource(hPackageInstance, PChar('ID_TEXTURE_FRAGMENT_SHADER'), RT_RCDATA) <> 0)
                then
                    pFragmentPrg := TResourceStream.Create(hPackageInstance,
                                                         PChar('ID_TEXTURE_FRAGMENT_SHADER'),
                                                         RT_RCDATA);

                // create texture shader
                m_pTextureShader := TQRShaderOpenGL.Create;

                // try to build shader
                if (not BuildShader(pVertexPrg, pFragmentPrg, m_pTextureShader)) then
                begin
                    Result := False;
                    Exit;
                end;
            finally
                // delete resource streams, if needed
                pVertexPrg.Free;
                pFragmentPrg.Free;
            end;
    end;

    // create MD3 model, if needed
    if (not Assigned(m_pMD3)) then
        m_pMD3 := TQRMD3Model.Create;

    pColor       := nil;
    pModelStream := nil;
    pNTStream    := nil;
    pTexture     := nil;

    try
        // load MD3 model from resources
        if (FindResource(hPackageInstance, PChar('ID_MD3_MODEL'), RT_RCDATA) <> 0)
        then
            pModelStream := TResourceStream.Create(hPackageInstance,
                                                   PChar('ID_MD3_MODEL'),
                                                   RT_RCDATA);

        pColor := TQRColor.Create(255, 255, 255, 255);

        // load model
        if (not m_pMD3.Load(pModelStream, pModelStream.Size)) then
        begin
            Result := False;
            Exit;
        end;

        m_pMD3.VertexFormat := [EQR_VF_TexCoords, EQR_VF_Colors];

        // create model matrix
        m_ModelMatrix := TQRMatrix4x4.Identity;
        m_ModelMatrix.Translate(TQRVector3D.Create(-0.18, -0.1, -0.7));
        m_ModelMatrix.Rotate(-(PI / 4.0), TQRVector3D.Create(1.0, 0.0, 0.0)); // -90�
        m_ModelMatrix.Rotate(-(PI / 4.0), TQRVector3D.Create(0.0, 0.0, 1.0)); // -45�
        m_ModelMatrix.Scale(TQRVector3D.Create(0.015, 0.015, 0.015));

        pTexture := TQRTexture.Create;
        LoadTexture(pTexture);
        SetLength(m_Textures, 1);
        m_Textures[0] := pTexture;
        pTexture := nil;
    finally
        pTexture.Free;
        pNTStream.Free;
        pModelStream.Free;
        pColor.Free;
    end;

    Result := True;
end;
//--------------------------------------------------------------------------------------------------
function TMainForm.GetFrame(index: NativeUInt; pModel: TQRMD3Model; useCollision: Boolean): IFrame;
var
    frameAdded: Boolean;
begin
    // get frame from cache
    if (m_pFrames.TryGetValue(index, Result)) then
        Exit;

    frameAdded := False;
    Result     := IFrame.Create(useCollision);

    try
        // frame still not cached, create and add it
        pModel.GetMesh(index, Result.m_pMesh, Result.m_pAABBTree);
        m_pFrames.Add(index, Result);
        frameAdded := True;
    finally
        // delete newly created frame only if an error occurred
        if (not frameAdded) then
        begin
            Result.Free;
            Result := nil;
        end;
    end;
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.DetectAndDrawCollisions(const modelMatrix: TQRMatrix4x4;
                                              const pAABBTree: TQRAABBTree;
                                        useShader, collisions: Boolean);
var
    rect:                                        TQRRect;
    rayPos, rayDir:                              TQRVector3D;
    invertMatrix:                                TQRMatrix4x4;
    determinant:                                 Single;
    pRay:                                        TQRRay;
    mesh:                                        TQRMesh;
    polygons, polygonToDraw:                     TQRPolygons;
    textures:                                    TQRTextures;
    polygonCount, polygonToDrawCount, i, offset: NativeUInt;
    uniform:                                     GLint;
begin
    if ((not collisions) or (not Assigned(pAABBTree))) then
        Exit;

    // calculate client rect in OpenGL coordinates
    rect := TQRRect.Create(-1.0, 1.25, 2.05, 2.35);

    // convert mouse position to OpenGL point, that will be used as ray start pos, and create ray dir
    rayPos := TQROpenGLHelper.MousePosToGLPoint(Handle, rect);
    rayDir := TQRVector3D.Create(0.0, 0.0, 1.0);

    // correct the ray position to follow the object location
    rayPos.X := rayPos.X + 0.18;
    rayPos.Y := rayPos.Y + 0.1;

    // transform the ray to be on the same coordinates system as the model
    invertMatrix := modelMatrix.Multiply(m_ViewMatrix).Multiply(m_ProjectionMatrix).Inverse(determinant);
    rayPos       := invertMatrix.Transform(rayPos);
    rayDir       := invertMatrix.Transform(rayDir);

    // create and populate ray from mouse position
    pRay     := TQRRay.Create;
    pRay.Pos := @rayPos;
    pRay.Dir := @rayDir;

    // get polygons to check for collision by resolving AABB tree
    pAABBTree.Resolve(pRay, polygons);

    polygonCount := Length(polygons);

    // iterate through polygons to check
    if (polygonCount > 0) then
        for i := 0 to polygonCount - 1 do
            // is polygon intersecting ray?
            if (TQRCollisionHelper.GetRayPolygonCollision(pRay, polygons[i])) then
            begin
                // add polygon in collision to resulting list
                SetLength(polygonToDraw, Length(polygonToDraw) + 1);
                polygonToDraw[Length(polygonToDraw) - 1] := polygons[i];
            end;

    polygonToDrawCount := Length(polygonToDraw);

    // found polgons to draw?
    if (polygonToDrawCount = 0) then
        Exit;

    SetLength(mesh, 1);

    mesh[0].m_Type      := EQR_VT_Triangles;
    mesh[0].m_CoordType := EQR_VC_XYZ;
    mesh[0].m_Stride    := 7;
    mesh[0].m_Format    := [EQR_VF_Colors];
    SetLength(mesh[0].m_Buffer, polygonToDrawCount * (mesh[0].m_Stride * 3));

    offset := 0;

    // iterate through polygons to draw
    for i := 0 to polygonToDrawCount - 1 do
    begin
        // build polygon to show
        mesh[0].m_Buffer[offset]      := polygonToDraw[i].Vertex1.X;
        mesh[0].m_Buffer[offset + 1]  := polygonToDraw[i].Vertex1.Y;
        mesh[0].m_Buffer[offset + 2]  := polygonToDraw[i].Vertex1.Z;
        mesh[0].m_Buffer[offset + 3]  := 1.0;
        mesh[0].m_Buffer[offset + 4]  := 0.0;
        mesh[0].m_Buffer[offset + 5]  := 0.0;
        mesh[0].m_Buffer[offset + 6]  := 1.0;
        mesh[0].m_Buffer[offset + 7]  := polygonToDraw[i].Vertex2.X;
        mesh[0].m_Buffer[offset + 8]  := polygonToDraw[i].Vertex2.Y;
        mesh[0].m_Buffer[offset + 9]  := polygonToDraw[i].Vertex2.Z;
        mesh[0].m_Buffer[offset + 10] := 0.8;
        mesh[0].m_Buffer[offset + 11] := 0.0;
        mesh[0].m_Buffer[offset + 12] := 0.2;
        mesh[0].m_Buffer[offset + 13] := 1.0;
        mesh[0].m_Buffer[offset + 14] := polygonToDraw[i].Vertex3.X;
        mesh[0].m_Buffer[offset + 15] := polygonToDraw[i].Vertex3.Y;
        mesh[0].m_Buffer[offset + 16] := polygonToDraw[i].Vertex3.Z;
        mesh[0].m_Buffer[offset + 17] := 1.0;
        mesh[0].m_Buffer[offset + 18] := 0.12;
        mesh[0].m_Buffer[offset + 19] := 0.2;
        mesh[0].m_Buffer[offset + 20] := 1.0;

        // go to next polygon
        Inc(offset, (mesh[0].m_Stride * 3));
    end;

    // do use shader?
    if (useShader) then
    begin
        // bind shader program
        m_pColorShader.Use(true);

        // get perspective (or projection) matrix slot from shader
        uniform := TQROpenGLHelper.GetUniform(m_pColorShader, EQR_SA_PerspectiveMatrix);

        // found it?
        if (uniform = -1) then
            raise Exception.Create('Program uniform not found - perspective');

        // connect perspective (or projection) matrix to shader
        glUniformMatrix4fv(uniform, 1, GL_FALSE, PGLfloat(m_ProjectionMatrix.GetPtr));

        // get view (or camera) matrix slot from shader
        uniform := TQROpenGLHelper.GetUniform(m_pColorShader, EQR_SA_CameraMatrix);

        // found it?
        if (uniform = -1) then
            raise Exception.Create('Program uniform not found - camera');

        // connect view (or camera) matrix to shader
        glUniformMatrix4fv(uniform, 1, GL_FALSE, PGLfloat(m_ViewMatrix.GetPtr));

        // unbind shader program
        m_pColorShader.Use(false);

        // configure OpenGL to draw polygons in collision
        glDisable(GL_TEXTURE_2D);
        glCullFace(GL_NONE);
        glDisable(GL_DEPTH_TEST);

        // draw mesh
        TQROpenGLHelper.Draw(mesh, modelMatrix, textures, m_pColorShader);

        // restore previous OpenGL parameters
        glEnable(GL_DEPTH_TEST);
        glCullFace(GL_FRONT);
        glEnable(GL_TEXTURE_2D);

        glFlush;
    end
    else
    begin
        glMatrixMode(GL_MODELVIEW);

        glPushMatrix;

        // place triangles into 3D world
        glLoadMatrixf(PGLfloat(modelMatrix.GetPtr));

        // configure OpenGL to draw polygons in collision
        glDisable(GL_TEXTURE_2D);
        glCullFace(GL_NONE);
        glDisable(GL_DEPTH_TEST);

        // draw polygons in collision with mouse pointer
        TQROpenGLHelper.Draw(mesh, modelMatrix, textures);

        // restore previous OpenGL parameters
        glEnable(GL_DEPTH_TEST);
        glCullFace(GL_FRONT);
        glEnable(GL_TEXTURE_2D);

        glPopMatrix;

        glFlush;
    end;
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.PrepareShaderToDrawModel(pShader: TQRShaderOpenGL; const textures: TQRTextures);
var
    uniform: GLint;
begin
    if (not Assigned(pShader)) then
        Exit;

    // bind shader program
    pShader.Use(True);

    // get perspective (or projection) matrix slot from shader
    uniform := TQROpenGLHelper.GetUniform(pShader, EQR_SA_PerspectiveMatrix);

    // found it?
    if (uniform = -1) then
        raise Exception.Create('Program uniform not found - perspective');

    // connect perspective (or projection) matrix to shader
    glUniformMatrix4fv(uniform, 1, GL_FALSE, PGLfloat(m_ProjectionMatrix.GetPtr));

    // get view (or camera) matrix slot from shader
    uniform := TQROpenGLHelper.GetUniform(pShader, EQR_SA_CameraMatrix);

    // found it?
    if (uniform = -1) then
        raise Exception.Create('Program uniform not found - camera');

    // connect view (or camera) matrix to shader
    glUniformMatrix4fv(uniform, 1, GL_FALSE, PGLfloat(m_ViewMatrix.GetPtr));

    // unbind shader program
    pShader.Use(False);
end;
//--------------------------------------------------------------------------------------------------
function TMainForm.LoadTexture(pTexture: TQRTexture): Boolean;
var
    hPackageInstance: THandle;
    pixelFormat:      Integer;
    pStream:          TResourceStream;
    pBitmap:          Vcl.Graphics.TBitmap;
    pPixels:          PByte;
begin
    if (not Assigned(pTexture)) then
    begin
        Result := False;
        Exit;
    end;

    pTexture.Name := 'watercan';

    // get module instance at which this form belongs
    hPackageInstance := FindClassHInstance(TMainForm);

    // found it?
    if (hPackageInstance = 0) then
    begin
        Result := False;
        Exit;
    end;

    pStream := nil;
    pBitmap := nil;
    pPixels := nil;

    try
        // found resource containing the vertex shader program to load?
        if (FindResource(hPackageInstance, PChar('ID_MD3_TEXTURE'), RT_RCDATA) <> 0)
        then
            pStream := TResourceStream.Create(hPackageInstance,
                                              PChar('ID_MD3_TEXTURE'),
                                              RT_RCDATA);

        if (not Assigned(pStream)) then
        begin
            Result := False;
            Exit;
        end;

        // load MD3 texture
        pBitmap := Vcl.Graphics.TBitmap.Create;
        pBitmap.LoadFromStream(pStream);

        if (pBitmap.PixelFormat = pf32bit) then
            pixelFormat := GL_RGBA
        else
            pixelFormat := GL_RGB;

        // convert bitmap to pixel array, and create OpenGL texture from array
        TQROpenGLHelper.BytesFromBitmap(pBitmap, pPixels, false, false);
        pTexture.Index := TQROpenGLHelper.CreateTexture(pBitmap.Width,
                                                        pBitmap.Height,
                                                        pixelFormat,
                                                        pPixels,
                                                        GL_NEAREST,
                                                        GL_NEAREST,
                                                        GL_TEXTURE_2D);
    finally
        if (Assigned(pPixels)) then
            FreeMem(pPixels);

        pBitmap.Free;
        pStream.Free;
    end;

    Result := True;
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.DrawModel(pModel: TQRMD3Model;
                      const textures: TQRTextures;
                        const matrix: TQRMatrix4x4;
                    index, nextIndex: NativeInt;
                 interpolationFactor: Double;
               useShader, collisions: Boolean);
var
    meshCount:                    NativeInt;
    pMeshToDraw, pNextMeshToDraw: PQRMesh;
    pAABBTree:                    TQRAABBTree;
    interpolated:                 Boolean;
    pFrame, pNextFrame:           IFrame;
begin
    // no model to draw?
    if (not Assigned(pModel)) then
        Exit;

    // get mesh count
    meshCount := pModel.GetMeshCount;

    // are indexes out of bounds?
    if ((index > meshCount) or (nextIndex > meshCount)) then
        Exit;

    pMeshToDraw     := nil;
    pNextMeshToDraw := nil;
    interpolated    := False;

    try
        // get frame to draw, and frame to interpolate with
        pFrame     := GetFrame(index,     pModel, collisions);
        pNextFrame := GetFrame(nextIndex, pModel, collisions);

        // do use shader?
        if (not useShader) then
        begin
            New(pMeshToDraw);

            // interpolate and get next mesh to draw
            TQRModelHelper.Interpolate(interpolationFactor,
                                       pFrame.m_pMesh,
                                       pNextFrame.m_pMesh,
                                       pMeshToDraw^);

            interpolated := True;
        end
        else
        begin
            // get meshes to send to shader
            pMeshToDraw     := @pFrame.m_pMesh;
            pNextMeshToDraw := @pNextFrame.m_pMesh;
        end;

        // get aligned-axis bounding box tree to use to detect collisions
        pAABBTree := pFrame.m_pAABBTree;

        // do use shader?
        if (not useShader) then
            // draw mesh
            TQROpenGLHelper.Draw(pMeshToDraw^, matrix, textures)
        else
        begin
            // prepare shader to draw the model
            PrepareShaderToDrawModel(m_pTextureShader, textures);

            // draw mesh
            TQROpenGLHelper.Draw(pMeshToDraw^,
                                 pNextMeshToDraw^,
                                 matrix,
                                 interpolationFactor,
                                 textures,
                                 m_pTextureShader);
        end;
    finally
        if (interpolated) then
            Dispose(pMeshToDraw);
    end;

    DetectAndDrawCollisions(matrix, pAABBTree, useShader, collisions);
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.OnIdle(pSender: TObject; var done: Boolean);
begin
    done := False;
    RenderGLScene;
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.RenderGLScene;
var
    now:         NativeUInt;
    elapsedTime: Double;
begin
    // calculate time interval
    now            := GetTickCount;
    elapsedTime    := (now - m_PreviousTime);
    m_PreviousTime :=  now;

    // clear scene
    glClearColor(0.0, 0.0, 0.0, 1.0);
    glClear(GL_COLOR_BUFFER_BIT or GL_DEPTH_BUFFER_BIT);

    // draw scene
    Draw(elapsedTime);

    glFlush;

    // finalize scene
    SwapBuffers(m_hDC);
end;
//--------------------------------------------------------------------------------------------------
procedure TMainForm.Draw(const elapsedTime: Double);
begin
    // draw model
    DrawModel(m_pMD3,
              m_Textures,
              m_ModelMatrix,
              0,
              0,
              m_InterpolationFactor,
              m_UseShader,
              m_Collisions);
end;
//--------------------------------------------------------------------------------------------------

end.