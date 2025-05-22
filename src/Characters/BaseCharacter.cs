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












}
