using System;
using Godot;

public partial class LeafSpawner : Node
{
	[Export] public Area3D CanopyArea;
	[Export] public PackedScene LeafScene;
	[Export] public float LeafSpacing = 0.5f;
	[Export] public float Jitter = 0.1f;
	[Export] public bool ClearOnRun = true;

	public override void _Ready()
	{
		if (CanopyArea == null || LeafScene == null)
		{
			GD.PrintErr("Missing CanopyArea or LeafScene.");
			return;
		}

		if (ClearOnRun)
			ClearLeaves();

		GenerateLeaves();
	}

	private void GenerateLeaves()
	{
		var shapeNode = CanopyArea.GetNodeOrNull<CollisionShape3D>("CollisionShape3D");
		if (shapeNode == null || shapeNode.Shape is not BoxShape3D boxShape)
		{
			GD.PrintErr("CanopyArea must have a BoxShape3D.");
			return;
		}

		Transform3D shapeGlobalTransform = shapeNode.GlobalTransform;
		Vector3 globalCenter = shapeGlobalTransform.Origin;

		// Convert local box size to global space using scale
		Vector3 halfExtents = boxShape.Size * 0.5f;
		Vector3 scale = shapeGlobalTransform.Basis.Scale;
		Vector3 globalHalfExtents = halfExtents * scale;

		// Build min/max corners in global space (axis aligned)
		Vector3 min = globalCenter - globalHalfExtents;
		Vector3 max = globalCenter + globalHalfExtents;

		for (float x = min.X; x <= max.X; x += LeafSpacing)
		{
			for (float y = min.Y; y <= max.Y; y += LeafSpacing)
			{
				for (float z = min.Z; z <= max.Z; z += LeafSpacing)
				{
					Vector3 position = new Vector3(x, y, z);

					if (Jitter > 0.0f)
					{
						position += new Vector3(
							GD.Randf() * Jitter - Jitter / 2,
							GD.Randf() * Jitter - Jitter / 2,
							GD.Randf() * Jitter - Jitter / 2
						);
					}

					SpawnLeaf(position);
				}
			}
		}

		GD.Print("Leaves generated.");
	}

	private void SpawnLeaf(Vector3 position)
	{
		Node3D leaf = LeafScene.Instantiate<Node3D>();
		leaf.GlobalTransform = new Transform3D(Basis.Identity, position);

		Callable.From(() => CanopyArea.AddChild(leaf));
	}

	private void ClearLeaves()
	{
		foreach (Node child in CanopyArea.GetChildren())
		{
			if (child is Node3D node && node != CanopyArea)
			{
				node.QueueFree();
			}
		}
	}
}

