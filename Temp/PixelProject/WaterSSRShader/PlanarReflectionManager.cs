using System;
using Godot;

[Tool]
public partial class PlanarReflectionManager : MeshInstance3D
{
	[Export] public Camera3D ReflectionCamera;
	[Export] public SubViewport ReflectionViewport;
	[Export] public ShaderMaterial WaterMaterial;

	public override void _Process(double delta)
	{
		if (ReflectionCamera == null || ReflectionViewport == null || WaterMaterial == null)
			return;

		// Assign reflection texture
		var tex = ReflectionViewport.GetTexture();
		if (tex != null)
			WaterMaterial.SetShaderParameter("reflection_texture", tex);

		// Get projection * view matrix
		var viewMatrix = BuildViewMatrix(ReflectionCamera);
		var projectionMatrix = BuildProjectionMatrix(ReflectionCamera);

		var viewProj = MultiplyMatrices(projectionMatrix, viewMatrix);

		// Send as float[16] to shader
		WaterMaterial.SetShaderParameter("reflection_view_proj", viewProj);
	}

	// Builds 4x4 view matrix as float[16]
	private float[] BuildViewMatrix(Camera3D camera)
	{
		Transform3D transform = camera.GlobalTransform;
		Basis basis = transform.Basis.Transposed(); // inverse rotation
		Vector3 origin = basis * -transform.Origin; // inverse translation

		return new float[]
		{
			basis.X.X, basis.X.Y, basis.X.Z, 0,
			basis.Y.X, basis.Y.Y, basis.Y.Z, 0,
			basis.Z.X, basis.Z.Y, basis.Z.Z, 0,
			origin.X,  origin.Y,  origin.Z,  1
		};
	}

	// Builds 4x4 projection matrix as float[16]
	private float[] BuildProjectionMatrix(Camera3D camera)
	{
		float near = camera.Near;
		float far = camera.Far;

		if (camera.Projection == Camera3D.ProjectionType.Perspective)
		{
			float fovY = Mathf.DegToRad(camera.Fov);
			float aspect = camera.GetViewport().GetWindow().Size.X / camera.GetViewport().GetWindow().Size.Y;

			float f = 1.0f / Mathf.Tan(fovY * 0.5f);

			return new float[]
			{
			f / aspect, 0, 0, 0,
			0, f, 0, 0,
			0, 0, (far + near) / (near - far), -1,
			0, 0, (2 * far * near) / (near - far), 0
			};
		}
		else if (camera.Projection == Camera3D.ProjectionType.Orthogonal)
		{
			float size = camera.Size;
			float aspect = camera.GetViewport().GetWindow().Size.X / camera.GetViewport().GetWindow().Size.Y;

			float right = size * 0.5f * aspect;
			float left = -right;
			float top = size * 0.5f;
			float bottom = -top;

			return new float[]
			{
			2.0f / (right - left), 0, 0, 0,
			0, 2.0f / (top - bottom), 0, 0,
			0, 0, -2.0f / (far - near), 0,
			-(right + left) / (right - left),
			-(top + bottom) / (top - bottom),
			-(far + near) / (far - near),
			1
			};
		}

		GD.PushError("Unsupported camera projection type.");
		return new float[16]; // Return zero matrix on error
	}

	// Multiplies two 4x4 matrices (row-major float[16])
	private float[] MultiplyMatrices(float[] a, float[] b)
	{
		float[] result = new float[16];

		for (int row = 0; row < 4; ++row)
		{
			for (int col = 0; col < 4; ++col)
			{
				result[row * 4 + col] =
					a[row * 4 + 0] * b[0 * 4 + col] +
					a[row * 4 + 1] * b[1 * 4 + col] +
					a[row * 4 + 2] * b[2 * 4 + col] +
					a[row * 4 + 3] * b[3 * 4 + col];
			}
		}

		return result;
	}




	// [Export] public SubViewport ReflectionViewport;
	// [Export] public Camera3D ReflectionCamera;

	// private ShaderMaterial _shader;

	// public override void _Ready()
	// {
	// 	if (ReflectionViewport == null || ReflectionCamera == null)
	// 	{
	// 		GD.PrintErr("Assign all required nodes in the inspector.");
	// 		return;
	// 	}

	// 	_shader = GetSurfaceOverrideMaterial(0) as ShaderMaterial;

	// 	if (_shader == null)
	// 	{
	// 		GD.PrintErr("WaterPlane material is not a ShaderMaterial.");
	// 		return;
	// 	}


	// 	// Flip the camera upside down
	// 	// ReflectionCamera.Rotation = new Vector3(Mathf.Pi, 0, 0);

	// 	// Feed SubViewport texture into shader
	// 	var viewportTexture = ReflectionViewport.GetTexture();
	// 	_shader.SetShaderParameter("reflection_view_proj", viewportTexture);
	// 	_shader.SetShaderParameter("reflection_texture", viewportTexture);

	// }

	// /*************  ✨ Windsurf Command ⭐  *************/
	// /// <summary>
	// /// Optional process function to position the reflection camera under the main camera.
	// /// Will mirror the main camera's position over the water plane and flip the direction
	// /// to look upwards.
	// /// </summary>
	// /*******  f15303a7-c592-4ff4-b0ee-ee87e648d3c3  *******/
	// public override void _Process(double delta)
	// {
	// 	// if (_shader == null || ReflectionCamera == null) return;

	// 	// // Optional: position the reflection camera under the main camera
	// 	// var mainCamera = GetViewport().GetCamera3D();
	// 	// if (mainCamera != null)
	// 	// {
	// 	// 	// Vector3 camPos = mainCamera.GlobalPosition;
	// 	// 	// camPos.Y = -camPos.Y + 2 * GlobalPosition.Y; // mirror over water
	// 	// 	// ReflectionCamera.GlobalPosition = camPos;

	// 	// 	// Vector3 camDir = mainCamera.GlobalTransform.Basis.Z;
	// 	// 	// camDir.Y = -camDir.Y;
	// 	// 	// //ReflectionCamera.LookAt(camPos + camDir, Vector3.Up);
	// 	// }
	// }
}