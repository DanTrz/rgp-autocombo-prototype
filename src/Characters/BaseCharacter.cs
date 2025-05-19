using Godot;
using System.Linq;

public abstract partial class BaseCharacter : CharacterBody3D
{
    public virtual string CharacterName { get; set; }

    public virtual int CharacterLevel { get; set; }

    public virtual int Health { get; set; }

    public virtual int MaxHealth { get; set; }

    public virtual int BaseDamage { get; set; }

    public virtual StateMachineManager StateMachine { get; set; }


    public virtual void TakeDamage(int amount)
    {
        //TODO: Add implementation

    }

    public override void _Ready()
    {
        StateMachine = GlobalUtil.GetAllChildNodesByType<StateMachineManager>(this).FirstOrDefault();
    }












}
