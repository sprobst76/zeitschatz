"""Email service for sending verification and notification emails."""

import logging
import smtplib
from email.mime.multipart import MIMEMultipart
from email.mime.text import MIMEText

from app.core.config import get_settings

logger = logging.getLogger(__name__)


class EmailService:
    """Service for sending emails via SMTP."""

    def __init__(self):
        self.settings = get_settings()

    def _is_configured(self) -> bool:
        """Check if SMTP is configured."""
        return bool(self.settings.smtp_host and self.settings.smtp_user)

    def _send(self, to: str, subject: str, html_body: str, text_body: str | None = None) -> bool:
        """Send an email.

        Args:
            to: Recipient email address
            subject: Email subject
            html_body: HTML content
            text_body: Plain text content (optional)

        Returns:
            True if sent successfully, False otherwise
        """
        if not self._is_configured():
            logger.warning(f"SMTP not configured, would send email to {to}: {subject}")
            return False

        try:
            msg = MIMEMultipart("alternative")
            msg["From"] = self.settings.smtp_from
            msg["To"] = to
            msg["Subject"] = subject

            if text_body:
                msg.attach(MIMEText(text_body, "plain"))
            msg.attach(MIMEText(html_body, "html"))

            if self.settings.smtp_tls:
                server = smtplib.SMTP(self.settings.smtp_host, self.settings.smtp_port)
                server.starttls()
            else:
                server = smtplib.SMTP(self.settings.smtp_host, self.settings.smtp_port)

            server.login(self.settings.smtp_user, self.settings.smtp_password)
            server.sendmail(self.settings.smtp_from, to, msg.as_string())
            server.quit()

            logger.info(f"Email sent to {to}: {subject}")
            return True

        except Exception as e:
            logger.error(f"Failed to send email to {to}: {e}")
            return False

    def send_verification_email(self, to: str, name: str, token: str) -> bool:
        """Send email verification link.

        Args:
            to: Recipient email
            name: User's name
            token: Verification token

        Returns:
            True if sent successfully
        """
        verify_url = f"{self.settings.frontend_url}/verify-email?token={token}"

        subject = "ZeitSchatz - Email bestätigen"

        html_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #4CAF50;">Willkommen bei ZeitSchatz!</h2>
            <p>Hallo {name},</p>
            <p>bitte bestätige deine Email-Adresse, indem du auf den folgenden Link klickst:</p>
            <p style="margin: 20px 0;">
                <a href="{verify_url}"
                   style="background-color: #4CAF50; color: white; padding: 12px 24px;
                          text-decoration: none; border-radius: 4px; display: inline-block;">
                    Email bestätigen
                </a>
            </p>
            <p>Oder kopiere diesen Link in deinen Browser:</p>
            <p style="word-break: break-all; color: #666;">{verify_url}</p>
            <p style="color: #999; font-size: 12px; margin-top: 30px;">
                Falls du dich nicht bei ZeitSchatz registriert hast, kannst du diese Email ignorieren.
            </p>
        </body>
        </html>
        """

        text_body = f"""
Willkommen bei ZeitSchatz!

Hallo {name},

bitte bestätige deine Email-Adresse, indem du den folgenden Link öffnest:

{verify_url}

Falls du dich nicht bei ZeitSchatz registriert hast, kannst du diese Email ignorieren.
        """

        return self._send(to, subject, html_body, text_body)

    def send_password_reset_email(self, to: str, name: str, token: str) -> bool:
        """Send password reset link.

        Args:
            to: Recipient email
            name: User's name
            token: Reset token

        Returns:
            True if sent successfully
        """
        reset_url = f"{self.settings.frontend_url}/reset-password?token={token}"

        subject = "ZeitSchatz - Passwort zurücksetzen"

        html_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #2196F3;">Passwort zurücksetzen</h2>
            <p>Hallo {name},</p>
            <p>du hast angefordert, dein Passwort zurückzusetzen. Klicke auf den folgenden Link:</p>
            <p style="margin: 20px 0;">
                <a href="{reset_url}"
                   style="background-color: #2196F3; color: white; padding: 12px 24px;
                          text-decoration: none; border-radius: 4px; display: inline-block;">
                    Passwort zurücksetzen
                </a>
            </p>
            <p>Oder kopiere diesen Link in deinen Browser:</p>
            <p style="word-break: break-all; color: #666;">{reset_url}</p>
            <p style="color: #999; font-size: 12px; margin-top: 30px;">
                Der Link ist 1 Stunde gültig. Falls du kein neues Passwort angefordert hast,
                kannst du diese Email ignorieren.
            </p>
        </body>
        </html>
        """

        text_body = f"""
Passwort zurücksetzen

Hallo {name},

du hast angefordert, dein Passwort zurückzusetzen. Öffne den folgenden Link:

{reset_url}

Der Link ist 1 Stunde gültig. Falls du kein neues Passwort angefordert hast,
kannst du diese Email ignorieren.
        """

        return self._send(to, subject, html_body, text_body)

    def send_family_invite_email(self, to: str, inviter_name: str, family_name: str, invite_code: str) -> bool:
        """Send family invitation.

        Args:
            to: Recipient email
            inviter_name: Name of person who sent invite
            family_name: Family name
            invite_code: Invitation code

        Returns:
            True if sent successfully
        """
        join_url = f"{self.settings.frontend_url}/join-family?code={invite_code}"

        subject = f"ZeitSchatz - Einladung zur Familie '{family_name}'"

        html_body = f"""
        <html>
        <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
            <h2 style="color: #FF9800;">Familieneinladung</h2>
            <p>Hallo!</p>
            <p><strong>{inviter_name}</strong> hat dich eingeladen, der Familie
               <strong>"{family_name}"</strong> bei ZeitSchatz beizutreten.</p>
            <p style="margin: 20px 0;">
                <a href="{join_url}"
                   style="background-color: #FF9800; color: white; padding: 12px 24px;
                          text-decoration: none; border-radius: 4px; display: inline-block;">
                    Einladung annehmen
                </a>
            </p>
            <p>Oder verwende diesen Einladungscode in der App:</p>
            <p style="font-size: 24px; font-weight: bold; color: #333;
                      background: #f5f5f5; padding: 10px; text-align: center;">
                {invite_code}
            </p>
            <p style="color: #999; font-size: 12px; margin-top: 30px;">
                Die Einladung ist 7 Tage gültig.
            </p>
        </body>
        </html>
        """

        text_body = f"""
Familieneinladung

Hallo!

{inviter_name} hat dich eingeladen, der Familie "{family_name}" bei ZeitSchatz beizutreten.

Öffne diesen Link, um beizutreten:
{join_url}

Oder verwende diesen Einladungscode in der App:
{invite_code}

Die Einladung ist 7 Tage gültig.
        """

        return self._send(to, subject, html_body, text_body)


# Singleton instance
_email_service: EmailService | None = None


def get_email_service() -> EmailService:
    """Get email service singleton."""
    global _email_service
    if _email_service is None:
        _email_service = EmailService()
    return _email_service
