from typing import Optional, List
from sqlmodel import Session, select
from uuid import UUID
from app.core.models import Ticket, StatusEnum, PriorityEnum, Comment

from app.modules.tickets.domain.models import (
    TicketCreate,
    TicketUpdate,
    CommentCreate,
    CommentUpdate,
)


# tickets
def get_ticket_by_id(session: Session, ticket_id: int) -> Optional[Ticket]:
    statement = select(Ticket).where(Ticket.id == ticket_id)
    return session.exec(statement).first()


def list_tickets(
    session: Session,
    requester_id: Optional[UUID] = None,
    assigned_agent_id: Optional[UUID] = None,
    status: Optional[StatusEnum] = None,
    priority: Optional[PriorityEnum] = None,
) -> List[Ticket]:
    statement = select(Ticket)
    if requester_id:
        statement = statement.where(Ticket.requester_id == requester_id)
    if assigned_agent_id:
        statement = statement.where(Ticket.assigned_agent_id == assigned_agent_id)
    if status:
        statement = statement.where(Ticket.status == status)
    if priority:
        statement = statement.where(Ticket.priority == priority)
    return session.exec(statement).all()


def create_ticket(
    session: Session, ticket_in: TicketCreate, requester_id: UUID
) -> Ticket:
    db_ticket = Ticket(
        title=ticket_in.title,
        description=ticket_in.description,
        priority=ticket_in.priority,
        status=ticket_in.status,
        requester_id=requester_id,
    )
    session.add(db_ticket)
    session.commit()
    session.refresh(db_ticket)
    return db_ticket


def update_ticket(
    session: Session, ticket: Ticket, ticket_in: TicketUpdate | None = None
) -> Ticket:
    ticket_data = ticket_in.model_dump(exclude_unset=True)
    ticket.sqlmodel_update(ticket_data)
    session.add(ticket)
    session.commit()
    session.refresh(ticket)
    return ticket


def delete_ticket(session: Session, ticket: Ticket):
    session.delete(ticket)
    session.commit()


# comments
def create_comment(
    session: Session, ticket_id: int, author_id: UUID, comment_in: CommentCreate
) -> Comment:
    db_comment = Comment(
        content=comment_in.content, ticket_id=ticket_id, author_id=author_id
    )
    session.add(db_comment)
    session.commit()
    session.refresh(db_comment)
    return db_comment


def get_comment_by_id(session: Session, comment_id: int) -> Optional[Comment]:
    statement = select(Comment).where(Comment.id == comment_id)
    return session.exec(statement).first()


def list_comments_for_ticket(session: Session, ticket_id: int) -> List[Comment]:
    statement = select(Comment).where(Comment.ticket_id == ticket_id)
    return session.exec(statement).all()


def update_comment(
    session: Session, comment: Comment, comment_in: CommentUpdate
) -> Comment:
    comment_data = comment_in.model_dump(exclude_unset=True)
    comment.sqlmodel_update(comment_data)
    session.add(comment)
    session.commit()
    session.refresh(comment)
    return comment


def delete_comment(session: Session, comment: Comment):
    session.delete(comment)
    session.commit()
