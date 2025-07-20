using System.Threading.Tasks;

public interface ICharacterState
{
    public Task Enter();
    public Task Exit();
    public Task ProcessUpdate(double delta);
    public Task PhysicsUpdate(double delta);

}

