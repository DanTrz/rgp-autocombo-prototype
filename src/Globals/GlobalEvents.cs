using Godot;
using System;

public partial class GlobalEvents : Node
{
    public static GlobalEvents Instance { get; private set; }
    public override void _Ready() { Instance = this; }

    public static Action<Node, Node[], Node[]> OnBattleLoading;
    public static Action<Node, Node[], Node[]> OnBattleStarted;
    public static Action<Node, Node[], Node[]> OnBattleEnded;
    public static Action<Node, Node[], Node[]> OnBattleEnding;
    public static Action<Node[]> OnBattleLootDropped; //TODO replace with  //Array[InventorySlotData]

    public string GetLookDirectionCardinal(Vector2 direction)
    {
        float angle = DirectionVectorToAngle(direction);
        return ConvertAngleToText(angle);
    }

    private float DirectionVectorToAngle(Vector2 direction)
    {
        float angle360 = Mathf.RadToDeg(direction.Angle());
        if (angle360 < 0)
        {
            angle360 += 360; // Normalize the angle to the range [0, 360)
        }
        return angle360;
    }

    private string ConvertAngleToText(float angle)
    {
        if (angle == 0 || angle >= 358 || (angle > 0 && angle < 43))
            return "east";

        if (angle == 45 || (angle > 43 && angle < 88))
            return "south_east";

        if (angle == 90 || (angle > 88 && angle < 133))
            return "south";

        if (angle == 135 || (angle > 133 && angle < 178))
            return "south_west";

        if (angle == 180 || (angle > 178 && angle < 223))
            return "west";

        if (angle == 225 || (angle > 223 && angle < 268))
            return "north_west";

        if (angle == 270 || (angle > 268 && angle < 313))
            return "north";

        if (angle == 315 || (angle > 313 && angle < 358))
            return "north_east";

        return "Error";
    }

}


// public Action<Godot.Collections.Array<Color>> OnPaletteChanged { get; set; }

// public Action<string, Const.BodyPartType, Color> OnMeshItemColorChanged { get; set; }

// public Action<string> OnEffectsChangesStarted { get; set; }

// public Action<string, Godot.Collections.Array<Color>> OnEffectsChangesEnded { get; set; }

// public Action<int> OnForcedPaletteSize { get; set; }

// public Action<Image> OnSpriteSheetCreated { get; set; }

// public Action<int, Vector3> OnModelTransformChanged { get; set; }

// public Action OnCamResetChanges { get; set; }
// public Action<float> OnSpriteSizeChanged { get; set; }


// func get_look_direction_cardinal(direction:Vector2) -> String:
// 	var angle = direction_vector_to_angle(direction)
// 	return convert_angle_to_text(angle)

// func direction_vector_to_angle(direction:Vector2) -> float:
// 	var angle360 = rad_to_deg(direction.angle())
// 	if angle360 < 0:
// 		angle360 += 360 # ## => / #90= S(Down) / 180 = W(Left) / 270 = N(Up) / 00 = E(Right) 
// 	return angle360

// func convert_angle_to_text(angle:float) -> String:
// 	if angle == 0 or angle >= 358 or(angle > 0 and angle < 43):
// 		return "east"

//     if angle == 45 or(angle > 43 and angle < 88):
// 		return "south_east"

//     if angle == 90 or(angle > 88 and angle < 133):
// 		return "south"

//     if angle == 135 or(angle > 133 and angle < 178):
// 		return "south_west"

//     if angle == 180 or(angle > 178 and angle < 223):
// 		return "west"

//     if angle == 225 or(angle > 223 and angle < 268):
// 		return "north_west"

//     if angle == 270 or(angle > 268 and angle < 313):
// 		return "north"

//     if angle == 315 or(angle > 313 and angle < 358):
// 		return "north_east"

//     return "Error"