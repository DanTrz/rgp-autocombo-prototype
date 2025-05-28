using System.Linq;
using Godot;

public abstract partial class BaseCharacter : CharacterBody3D
{
    public virtual string CharacterName { get; set; }

    public virtual int CharacterLevel { get; set; }

    public virtual int Health { get; set; }

    public virtual int MaxHealth { get; set; }

    public virtual int BaseDamage { get; set; }

    public virtual StateMachineManager StateMachine { get; set; }


    public virtual bool IsModel3D { get; set; } = false; //TODO: remove - this is just for testing the TEMP 3D Model


    public virtual void TakeDamage(int amount)
    {
        //TODO: Add implementation

    }

    public override void _Ready()
    {
        StateMachine = GlobalUtil.GetAllChildNodesByType<StateMachineManager>(this).FirstOrDefault();
    }

    public void SetCharacterVelocity(BaseCharacter charMainNode, Vector3 newVelocity, string source)
    {
        if (charMainNode.Velocity != newVelocity) // Log only if there's an actual change
        {
            Log.Info($"VELOCITY CHANGE by '{source}': From {charMainNode.Velocity} To {newVelocity}");
        }
        charMainNode.Velocity = newVelocity; // Set the actual engine velocity
        //_loggedVelocity = newVelocity; // Keep our shadow property in sync
    }












}
