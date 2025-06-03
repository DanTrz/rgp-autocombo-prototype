// GodRayManager.cs
using System; // For Math
using Godot;

//[Tool]
public partial class GodRayManager : Node3D
{
    // [ExportToolButton("Force Rebuild Rays")]
    // public Callable ForceResetRaysButton => Callable.From(RecalculateRays);

    [ExportGroup("References")]
    [Export] private Mesh _meshResource { get; set; }
    [Export] private DirectionalLight3D _mainDirectionalLight { get; set; }
    [Export] private Camera3D _mainCamera { get; set; }
    [Export] private MultiMeshInstance3D _rayMultiMeshInstance { get; set; }

    private int _numberOfRays = 20;
    [ExportGroup("Ray Properties")]
    [Export(PropertyHint.Range, "1,2000,1")]
    public int NumberOfRays = 20;
    // {
    //     get => _numberOfRays;
    //     set
    //     {
    //         if (_numberOfRays == value) return;
    //         _numberOfRays = Math.Max(1, value);
    //         if (Engine.IsEditorHint() && IsInsideTree())
    //         {
    //             Callable.From(RebuildRays).CallDeferred();
    //             NotifyPropertyListChanged();
    //         }
    //         else if (IsInsideTree())
    //         {
    //             Callable.From(RebuildRays).CallDeferred();
    //         }
    //     }
    // }

    [Export(PropertyHint.Range, "1.0,100.0,0.1")] public float MaxRayLength { get; set; } = 30.0f;
    [Export(PropertyHint.Range, "0.01,5.0,0.01")] public float RayBaseWidth { get; set; } = 0.5f;
    [Export] public Color InitialRayColor { get; set; } = new Color(1.0f, 0.95f, 0.8f, 0.2f); // Increased default alpha
    [Export(PropertyHint.Range, "0.0,10.0,0.05")] public float RayIntensity { get; set; } = 1.5f; // Increased default
    [Export(PropertyHint.Range, "0.80,1.0,0.005")] public float RayDecay { get; set; } = 0.97f;

    [ExportGroup("Distribution Parameters")]
    [Export(PropertyHint.Range, "0.1,100.0,0.1")] public float EmissionAreaWidth { get; set; } = 20.0f;
    [Export(PropertyHint.Range, "0.1,100.0,0.1")] public float EmissionAreaHeight { get; set; } = 20.0f;
    [Export(PropertyHint.Range, "0.0,50.0,0.1")] public float EmissionDistanceOffset { get; set; } = 5.0f;

    private ShaderMaterial _rayMaterial;

    public override void _Ready()
    {

        //Callable.From(InitialSetup).CallDeferred();
        Callable.From(SimpleMeshInstanceSetup).CallDeferred();
    }

    private void SimpleMeshInstanceSetup()
    {
        // Create the multimesh.
        var Multimesh = _rayMultiMeshInstance.Multimesh;
        // Set the format first.
        //Multimesh.TransformFormat = MultiMesh.TransformFormatEnum.Transform3D;
        // Then resize (otherwise, changing the format is not allowed)
        Multimesh.InstanceCount = 5;
        // Maybe not all of them should be visible at first.
        Multimesh.VisibleInstanceCount = 5;

        // Set the transform of the instances.
        for (int i = 0; i < Multimesh.InstanceCount; i++)
        {
            var position = new Vector3((i * 3f) - 5, 5, 5);
            var normalizedAxis = new Vector3(1, 1, 1).Normalized();
            Basis newBasis = new Basis(normalizedAxis, Mathf.DegToRad(-20f));
            Multimesh.SetInstanceTransform(i, new Transform3D(newBasis, position)); //     Multimesh.SetInstanceTransform(i, new Transform3D(Basis.Identity, position));
            GD.Print($"Instance {i} set to {position}");
        }

    }

    private void InitialSetup()
    {
        GD.Print("--- GodRayManager: _Ready() called ---");

        // Check essential direct references first
        bool referencesValid = true;
        if (_mainDirectionalLight == null) { GD.PrintErr("GodRayManager Error: _mainDirectionalLight is not assigned in Inspector!"); referencesValid = false; }
        if (_mainCamera == null) { GD.PrintErr("GodRayManager Error: _mainCamera is not assigned in Inspector!"); referencesValid = false; }
        if (_rayMultiMeshInstance == null) { GD.PrintErr("GodRayManager Error: _rayMultiMeshInstance is not assigned in Inspector!"); referencesValid = false; }
        if (_meshResource == null) { GD.PrintErr("GodRayManager Error: _meshResource is not assigned in Inspector!"); referencesValid = false; }

        if (!referencesValid)
        {
            GD.PrintErr("GodRayManager: One or more essential exported references are not set. Disabling script.");
            SetProcess(false);
            return;
        }
        GD.Print("GodRayManager: All direct references seem assigned.");

        // Get the ShaderMaterial
        _rayMaterial = _rayMultiMeshInstance.MaterialOverride as ShaderMaterial;
        if (_rayMaterial != null)
        {
            GD.Print("GodRayManager: Found _rayMaterial from MaterialOverride.");
        }
        else
        {
            if (_rayMultiMeshInstance.Multimesh?.Mesh?.GetSurfaceCount() > 0)
            {
                _rayMaterial = _rayMultiMeshInstance.Multimesh.Mesh.SurfaceGetMaterial(0) as ShaderMaterial;
                if (_rayMaterial != null) GD.Print("GodRayManager: Found _rayMaterial from MultiMesh.Mesh surface 0.");
            }
        }

        // ... after _rayMaterial assignment block ...
        if (_rayMaterial != null && IsInstanceValid(_rayMaterial))
        {
            GD.Print("GodRayManager: _rayMaterial obtained successfully. Shader path: ", _rayMaterial.Shader?.ResourcePath ?? "N/A");
        }
        else
        {
            GD.PrintErr("GodRayManager: _rayMaterial is NULL even after checks. This is a critical issue.");
            // No point in continuing if material is null
            SetProcess(false);
            return;
        }

        if (_rayMaterial == null)
        {
            GD.PrintErr("GodRayManager: RayMultiMeshInstance needs a ShaderMaterial assigned. Disabling script processing.");
            SetProcess(false);
            return;
        }
        GD.Print("GodRayManager: _rayMaterial successfully obtained.");

        Callable.From(InitialSetupDeferred).CallDeferred();
    }

    private void InitialSetupDeferred()
    {
        GD.Print("GodRayManager: InitialSetupDeferred() called.");
        if (!IsInstanceValid(_rayMultiMeshInstance) || !IsInstanceValid(_mainCamera) || !IsInstanceValid(_meshResource) || !IsInstanceValid(_mainDirectionalLight) || !IsInstanceValid(_rayMaterial))
        {
            GD.PrintErr("GodRayManager: A critical node became invalid before deferred setup. Aborting.");
            SetProcess(false);
            return;
        }
        RebuildRays(); // This will configure, populate, and update uniforms
        GD.Print("GodRayManager: Initial RebuildRays completed via deferred call.");
    }

    void EnsureMultiMeshConfiguration()
    {
        GD.Print("GodRayManager: EnsureMultiMeshConfiguration() called.");
        MultiMesh mm = _rayMultiMeshInstance.Multimesh;
        if (mm == null)
        {
            GD.Print("GodRayManager: MultiMesh resource was null. Creating new one.");
            mm = new MultiMesh();
            _rayMultiMeshInstance.Multimesh = mm;
        }

        if (mm.TransformFormat != MultiMesh.TransformFormatEnum.Transform3D)
        {
            GD.PrintRich($"[color=orange]GodRayManager Warning: MultiMesh TransformFormat was '{mm.TransformFormat}'. Setting to 'Transform3D'.[/color]");
            mm.TransformFormat = MultiMesh.TransformFormatEnum.Transform3D;
        }
        if (!mm.UseCustomData)
        {
            GD.PrintRich("[color=orange]GodRayManager Warning: MultiMesh UseCustomData was 'false'. Setting to 'true'.[/color]");
            mm.UseCustomData = true;
        }

        if (mm.Mesh != _meshResource)
        {
            if (_meshResource != null)
            {
                GD.Print("GodRayManager Info: Setting MultiMesh.Mesh from _meshResource.");
                mm.Mesh = _meshResource;
            }
            else if (mm.Mesh == null)
            {
                GD.PrintErr("GodRayManager Error: No mesh assigned to MultiMesh and _meshResource is null.");
                return;
            }
        }
        if (mm.Mesh == null)
        {
            GD.PrintErr("GodRayManager Error: MultiMesh.Mesh is still null after configuration attempt.");
            return;
        }

        if (mm.InstanceCount != _numberOfRays)
        {
            GD.Print($"GodRayManager: Updating MultiMesh InstanceCount from {mm.InstanceCount} to {_numberOfRays}.");
            mm.InstanceCount = _numberOfRays;
        }
        GD.Print("GodRayManager: EnsureMultiMeshConfiguration() finished.");
    }

    void PopulateInitialRayTransforms()
    {
        GD.Print("GodRayManager: PopulateInitialRayTransforms() called.");
        MultiMesh mm = _rayMultiMeshInstance.Multimesh;

        if (mm == null || mm.Mesh == null || _mainCamera == null)
        {
            GD.PrintErr("PopulateInitialRayTransforms: MultiMesh, its Mesh, or MainCamera is not ready/assigned. Cannot populate.");
            return;
        }
        if (mm.InstanceCount == 0)
        {
            GD.Print("PopulateInitialRayTransforms: InstanceCount is 0, nothing to populate.");
            return;
        }

        Basis camBasis = _mainCamera.GlobalTransform.Basis;
        Vector3 camOrigin = _mainCamera.GlobalTransform.Origin;
        Vector3 camForward = -camBasis.Z;
        Vector3 planeCenter = camOrigin + camForward * EmissionDistanceOffset;

        GD.Print($"PopulateInitialRayTransforms: Populating {mm.InstanceCount} instances. PlaneCenter: {planeCenter}");

        for (int i = 0; i < mm.InstanceCount; i++)
        {


            var position = new Vector3((i * 1.5f) - 5, 5, 5);
            var normalizedAxis = new Vector3(1, 1, 1).Normalized();
            Basis newBasis = new Basis(normalizedAxis, Mathf.DegToRad(-20f));
            mm.SetInstanceTransform(i, new Transform3D(newBasis, position)); //     Multimesh.SetInstanceTransform(i, new Transform3D(Basis.Identity, position));
            GD.Print($"Instance {i} set to {position}");

            // float randX = (GD.Randf() - 0.5f) * EmissionAreaWidth;
            // float randY = (GD.Randf() - 0.5f) * EmissionAreaHeight;
            // Vector3 instanceOrigin = planeCenter + camBasis.X * randX + camBasis.Y * randY;
            // Transform3D initialTransform = new Transform3D(Basis.Identity, instanceOrigin);

            // try
            // {
            //     mm.SetInstanceTransform(i, initialTransform);
            //     if (mm.UseCustomData)
            //     {
            //         mm.SetInstanceCustomData(i, new Color(GD.Randf(), 0f, 0f, 0f));
            //     }
            // }
            // catch (Exception e)
            // {
            //     GD.PrintErr($"Error setting instance data for index {i}: {e.Message}");
            //     return;
            // }
        }
        GD.Print("GodRayManager: PopulateInitialRayTransforms() finished.");

        // for (int i = 0; i < Multimesh.InstanceCount; i++)
        // {
        //     var position = new Vector3((i * 1) - 5, 5, 5);
        //     var normalizedAxis = new Vector3(1, 1, 1).Normalized();
        //     Basis newBasis = new Basis(normalizedAxis, Mathf.DegToRad(-20f));
        //     Multimesh.SetInstanceTransform(i, new Transform3D(newBasis, position)); //     Multimesh.SetInstanceTransform(i, new Transform3D(Basis.Identity, position));
        //     GD.Print($"Instance {i} set to {position}");
        // }
    }

    // public override void _Process(double delta)
    // {
    //     if (!IsInstanceValid(_mainDirectionalLight) || !IsInstanceValid(_mainCamera) || !IsInstanceValid(_rayMaterial))
    //     {
    //         if (Engine.IsEditorHint() && GetProcessMode() != ProcessModeEnum.Disabled)
    //         {
    //             GD.PrintErr("GodRayManager (_Process): Essential node reference became invalid. Disabling further processing.");
    //             SetProcess(false);
    //         }
    //         return;
    //     }
    //     UpdateShaderUniforms();
    // }

    void UpdateShaderUniforms()
    {
        GD.Print($"GodRayManager: UpdateShaderUniforms CALLED at frame {Engine.GetFramesDrawn()}"); // Frame count for timing
                                                                                                    // Ensure nodes are still valid before accessing them
        if (_rayMaterial == null || !IsInstanceValid(_rayMaterial) ||
            _mainDirectionalLight == null || !IsInstanceValid(_mainDirectionalLight) ||
            _mainCamera == null || !IsInstanceValid(_mainCamera))
        {
            GD.PrintErr("UpdateShaderUniforms: Material or essential nodes are null/invalid. Skipping update.");
            return;
        }


        // This check is crucial
        if (_rayMaterial == null || !IsInstanceValid(_rayMaterial) ||
            _mainDirectionalLight == null || !IsInstanceValid(_mainDirectionalLight) ||
            _mainCamera == null || !IsInstanceValid(_mainCamera))
        {
            // This print might be too spammy if called every frame. 
            // Consider only printing if state changes or once.
            // GD.PrintErr("UpdateShaderUniforms: Material or essential nodes are null/invalid. Skipping update.");
            return;
        }

        // GD.Print("GodRayManager: UpdateShaderUniforms() CALLED."); // DIAGNOSTIC - Can be very spammy

        Vector3 lightDirWorld = -_mainDirectionalLight.GlobalTransform.Basis.Z.Normalized();
        _rayMaterial.SetShaderParameter("u_light_direction_world", lightDirWorld);
        _rayMaterial.SetShaderParameter("u_light_color", InitialRayColor.SrgbToLinear());
        _rayMaterial.SetShaderParameter("u_light_intensity", RayIntensity);
        _rayMaterial.SetShaderParameter("u_max_ray_length", MaxRayLength);
        _rayMaterial.SetShaderParameter("u_ray_base_width", RayBaseWidth);
        _rayMaterial.SetShaderParameter("u_ray_decay_factor", RayDecay);

        Transform3D camGlobalTransform = _mainCamera.GlobalTransform;
        Projection proj = _mainCamera.GetCameraProjection();

        _rayMaterial.SetShaderParameter("u_projection_matrix", proj);
        _rayMaterial.SetShaderParameter("u_inv_projection_matrix", proj.Inverse());
        _rayMaterial.SetShaderParameter("u_view_matrix", camGlobalTransform.AffineInverse());
        _rayMaterial.SetShaderParameter("u_inv_view_matrix", camGlobalTransform);
        _rayMaterial.SetShaderParameter("u_camera_pos_world", camGlobalTransform.Origin);
        _rayMaterial.SetShaderParameter("u_camera_right_world", camGlobalTransform.Basis.X.Normalized());

        // GD.Print($"GodRayManager: u_light_intensity = {RayIntensity}, u_light_color.a = {InitialRayColor.A}"); // DIAGNOSTIC
        // GD.Print($"GodRayManager: u_camera_pos_world = {_mainCamera.GlobalPosition}"); // DIAGNOSTIC

        // ... after setting all light uniforms ...
        _rayMaterial.SetShaderParameter("u_ray_decay_factor", RayDecay);
        GD.Print($"GodRayManager: Set u_light_intensity to: {RayIntensity}"); // DIAGNOSTIC
        GD.Print($"GodRayManager: Set u_max_ray_length to: {MaxRayLength}");   // DIAGNOSTIC

        // ... after setting all camera uniforms ...
        _rayMaterial.SetShaderParameter("u_camera_right_world", camGlobalTransform.Basis.X.Normalized());
        GD.Print($"GodRayManager: Set u_camera_pos_world to: {camGlobalTransform.Origin}"); // DIAGNOSTIC
        GD.Print("GodRayManager: UpdateShaderUniforms FINISHED setting parameters."); // DIAGNOSTIC

    }

    public void RebuildRays()
    {
        GD.Print("GodRayManager: RebuildRays() called.");
        if (!IsInsideTree() && !Engine.IsEditorHint())
        {
            if (!Engine.IsEditorHint())
            {
                GD.Print("RebuildRays: Not in scene tree and not in editor. Skipping.");
                return;
            }
        }

        if (_rayMultiMeshInstance == null || _mainCamera == null || _meshResource == null) // Check _meshResource too
        {
            GD.PrintErr("RebuildRays: Essential references missing. Cannot rebuild.");
            return;
        }

        EnsureMultiMeshConfiguration();

        if (_rayMultiMeshInstance.Multimesh == null || _rayMultiMeshInstance.Multimesh.Mesh == null)
        {
            GD.PrintErr("RebuildRays: MultiMesh or its Mesh is null after EnsureMultiMeshConfiguration. Aborting populate/update.");
            return;
        }

        PopulateInitialRayTransforms();
        UpdateShaderUniforms();
        GD.Print("GodRayManager: Rays rebuilt. Count: ", _numberOfRays);
    }

    private void RecalculateRays()
    {
        GD.Print("GodRayManager: RecalculateRays button pressed.");
        Callable.From(RebuildRays).CallDeferred(); // Deferring is good for editor actions
    }
}