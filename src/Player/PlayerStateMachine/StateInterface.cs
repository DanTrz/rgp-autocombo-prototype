public interface IState
{
    public void Enter();
    public void Exit();
    public void ProcessUpdate(double delta);
    public void PhysicsUpdate(double delta);

}

