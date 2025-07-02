using System.Collections.Generic;
using Godot;

public partial class SphereDebugVisualizer : MultiMeshInstance3D
{
	// [Export] public float SphereRadius { get; set; } = 0.2f;
	// [Export] public Material BaseMaterial { get; set; }

	private List<Vector3> _positions = new();
	private List<Color> _colors = new();

	public override void _Ready()
	{
		if (Multimesh == null)
		{
			Multimesh = new MultiMesh();
			this.Multimesh = Multimesh;
		}
	}

	// private Mesh GenerateSphereMesh()
	// {
	// 	var sphere = new SphereMesh
	// 	{
	// 		Radius = SphereRadius,
	// 		Height = SphereRadius * 2,
	// 		Rings = 6,
	// 		RadialSegments = 8
	// 	};
	// 	if (BaseMaterial != null)
	// 		this.MaterialOverride = BaseMaterial;
	// 	return sphere;
	// }

	public void AddPoint(Vector3 position, Color color)
	{
		position = ToLocal(position);
		_positions.Add(position);
		_colors.Add(color);
		UpdateMultimesh();
	}

	public void ClearAll()
	{
		_positions.Clear();
		_colors.Clear();
		UpdateMultimesh();
	}

	private void UpdateMultimesh()
	{
		if (Multimesh == null)
			return;

		Multimesh.InstanceCount = _positions.Count;

		for (int i = 0; i < _positions.Count; i++)
		{
			Transform3D xform = new Transform3D(Basis.Identity, _positions[i]);
			Multimesh.SetInstanceTransform(i, xform);
			Multimesh.SetInstanceColor(i, _colors[i]);
		}
	}
}