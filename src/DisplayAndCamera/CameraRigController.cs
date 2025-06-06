using System;
using Godot;

public partial class CameraRigController : Node3D
{
	[Export] public float CamMaxLimitX = 0.5f;
	[Export] public float CamMinLimitX = 0.5f;
	[Export] public float HorizontalAcceleration = 0.5f;
	[Export] public float VerticalAcceleration = 0.5f;
	[Export] public float MouseAcceleration = 0.002f;

	[Export] public float CameraSpeed = 7.0f;

	[Export] public Node3D RotationPivotPoint;


	[Export] public CameraPixelSnap MainCamera;


	public override void _Process(double delta)
	{
		//GET 2D INputs 
		Vector2 inputDirectionVec2D = new();
		inputDirectionVec2D.Y = Input.GetActionStrength("cam_back") - Input.GetActionStrength("cam_forward");
		inputDirectionVec2D.X = Input.GetActionStrength("cam_right") - Input.GetActionStrength("cam_left");

		//TRanslated the 2D input to a 3D Vector (both lines do the same thing)
		Vector3 inputDirectionVec3D = new Vector3(inputDirectionVec2D.X, 0, -inputDirectionVec2D.Y).Normalized();
		//Vector3 inputDirectionVec3D = (Basis.X * inputDirectionVec2D.X - Basis.Z * inputDirectionVec2D.Y).Normalized();

		if (inputDirectionVec3D != Vector3.Zero)
			MoveCamRig(inputDirectionVec3D, (float)delta);


		//GET 2D INputs for rotation
		Vector2 inputRotationVec2D = new();
		inputRotationVec2D.X = Input.GetActionStrength("cam_orbit_right") - Input.GetActionStrength("cam_orbit_left");
		//Translated the 2D input to a 3D Vector For Rotation
		Vector3 rotationVec3D = new Vector3(inputRotationVec2D.X, 0, -inputRotationVec2D.Y).Normalized();

		if (rotationVec3D != Vector3.Zero)
			RotateAroungPivot(rotationVec3D, (float)delta);
	}

	private void MoveCamRig(Vector3 direction, float delta)
	{
		//USING 3D Vector
		Position += direction * CameraSpeed * (float)delta;

		//BELOW USED 2D Vector
		// Position += Basis.X * vector.X * CameraSpeed * (float)delta;
		// Position += -Basis.Z * vector.Y * CameraSpeed * (float)delta;
	}

	private void RotateCamRig(Vector3 direction, float delta)
	{

		var originalRotation = RotationPivotPoint.GlobalRotation;

		RotateY(Mathf.DegToRad(direction.X) * delta * CameraSpeed); //Rotate to a direction by a certain speed

		RotationPivotPoint.GlobalRotation = originalRotation;

		//MainCamera.LookAt(RotationPivotPoint.GlobalPosition);
	}

	private void RotateAroungPivot(Vector3 direction, float delta)
	{
		var pivotPointGlobalPos = RotationPivotPoint.GlobalPosition;
		var pivotPointGlobalRotation = RotationPivotPoint.GlobalRotation;

		// Calculate the current offset from the rig to the pivot point
		Vector3 distanceFromPivotPoint = GlobalPosition - pivotPointGlobalPos;

		//Define the Rotation Direction (= Rotation angle)
		float rotationAngle = Mathf.DegToRad(direction.X) * delta * CameraSpeed;

		// Rotate the offset vector around the pivot's Y-axis based on input.X
		Basis rotation = new Basis(Vector3.Up.Normalized(), rotationAngle);
		distanceFromPivotPoint = rotation * distanceFromPivotPoint; //Adds rotation to distance from pivotPoint)

		// Update the rigs position to add the new position (that has the rotation)
		Position = pivotPointGlobalPos + distanceFromPivotPoint;
		//CamPitch.RotateY(Mathf.DegToRad(direction.X) * delta * CameraSpeed);

		// Make the camera look at the pivot point
		MainCamera.LookAt(pivotPointGlobalPos);

		//Restore the rotation of the pivot point
		RotationPivotPoint.GlobalPosition = pivotPointGlobalPos;
		RotationPivotPoint.GlobalRotation = pivotPointGlobalRotation;
	}
}
