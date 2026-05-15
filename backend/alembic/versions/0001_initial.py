"""initial schema

Revision ID: 0001
Revises:
Create Date: 2026-05-16
"""

from alembic import op
import sqlalchemy as sa

revision = "0001"
down_revision = None
branch_labels = None
depends_on = None


def upgrade() -> None:
    op.create_table(
        "mangas",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("name", sa.String(255), nullable=False),
        sa.Column("cover_url", sa.Text, nullable=False),
        sa.Column("background_url", sa.Text, nullable=True),
        sa.Column("created_at", sa.DateTime, nullable=False),
        sa.Column("updated_at", sa.DateTime, nullable=False),
    )

    op.create_table(
        "chapters",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("manga_id", sa.Integer, sa.ForeignKey("mangas.id", ondelete="CASCADE"), nullable=False),
        sa.Column("number", sa.Integer, nullable=False),
        sa.Column("title", sa.String(255), nullable=False, server_default="''"),
        sa.Column("updated_at", sa.DateTime, nullable=False),
    )

    op.create_table(
        "pages",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("chapter_id", sa.Integer, sa.ForeignKey("chapters.id", ondelete="CASCADE"), nullable=False),
        sa.Column("page_index", sa.Integer, nullable=False),
        sa.Column("type", sa.String(20), nullable=False, server_default="'image'"),
        sa.Column("url", sa.Text, nullable=False),
    )

    op.create_table(
        "users",
        sa.Column("uid", sa.String(128), primary_key=True),
        sa.Column("email", sa.String(255), nullable=True),
        sa.Column("display_name", sa.String(255), nullable=True),
        sa.Column("photo_url", sa.Text, nullable=True),
        sa.Column("is_admin", sa.Boolean, nullable=False, server_default="0"),
        sa.Column("is_vip", sa.Boolean, nullable=False, server_default="0"),
        sa.Column("vip_until", sa.DateTime, nullable=True),
        sa.Column("created_at", sa.DateTime, nullable=False),
        sa.Column("updated_at", sa.DateTime, nullable=False),
    )

    op.create_table(
        "topups",
        sa.Column("id", sa.String(128), primary_key=True),
        sa.Column("user_id", sa.String(128), sa.ForeignKey("users.uid", ondelete="CASCADE"), nullable=False),
        sa.Column("user_name", sa.String(255), nullable=True),
        sa.Column("package_label", sa.String(100), nullable=False, server_default="''"),
        sa.Column("package_value", sa.Integer, nullable=False, server_default="0"),
        sa.Column("price_text", sa.String(50), nullable=False, server_default="''"),
        sa.Column("amount", sa.DECIMAL(10, 2), nullable=False, server_default="0"),
        sa.Column("amount_expected", sa.DECIMAL(10, 2), nullable=False, server_default="0"),
        sa.Column("payment_method", sa.String(50), nullable=False, server_default="'promptpay'"),
        sa.Column("status", sa.String(30), nullable=False, server_default="'pending'"),
        sa.Column("ref_code", sa.String(100), nullable=False, server_default="''"),
        sa.Column("referral", sa.String(100), nullable=True),
        sa.Column("slip_file_name", sa.String(255), nullable=True),
        sa.Column("slip_download_url", sa.Text, nullable=True),
        sa.Column("platform", sa.String(20), nullable=False, server_default="'mobile'"),
        sa.Column("role_target", sa.String(20), nullable=False, server_default="'vip'"),
        sa.Column("duration_days", sa.Integer, nullable=False, server_default="30"),
        sa.Column("qr_amount", sa.DECIMAL(10, 2), nullable=True),
        sa.Column("qr_target", sa.String(50), nullable=True),
        sa.Column("expires_at", sa.DateTime, nullable=True),
        sa.Column("paid_at", sa.DateTime, nullable=True),
        sa.Column("fail_reason", sa.Text, nullable=True),
        sa.Column("slipok_payload", sa.JSON, nullable=True),
        sa.Column("slipok_trans_ref", sa.String(100), nullable=True),
        sa.Column("created_at", sa.DateTime, nullable=False),
        sa.Column("updated_at", sa.DateTime, nullable=False),
    )

    op.create_table(
        "website_carousel_images",
        sa.Column("id", sa.Integer, primary_key=True, autoincrement=True),
        sa.Column("url", sa.Text, nullable=False),
        sa.Column("sort_order", sa.Integer, nullable=False, server_default="0"),
    )


def downgrade() -> None:
    op.drop_table("website_carousel_images")
    op.drop_table("topups")
    op.drop_table("users")
    op.drop_table("pages")
    op.drop_table("chapters")
    op.drop_table("mangas")
