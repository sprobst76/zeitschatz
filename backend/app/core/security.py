from fastapi import Depends, Header, HTTPException, status


def get_current_user(
    x_user_id: int | None = Header(default=None, alias="X-User-Id"),
    x_user_role: str | None = Header(default=None, alias="X-User-Role"),
):
    """
    Placeholder-Auth bis PIN/JWT implementiert ist.
    Nutzt Header X-User-Id und X-User-Role (parent|child).
    """
    if not x_user_id or not x_user_role:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Missing auth headers (X-User-Id, X-User-Role).",
        )
    return {"id": x_user_id, "role": x_user_role.lower()}


def require_role(required: str):
    def dependency(user=Depends(get_current_user)):
        if user["role"] != required:
            raise HTTPException(status_code=status.HTTP_403_FORBIDDEN, detail="Forbidden for this role")
        return user

    return dependency
