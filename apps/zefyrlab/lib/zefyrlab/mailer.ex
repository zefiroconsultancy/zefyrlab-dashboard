defmodule Zefyrlab.Mailer do
  @moduledoc """
  Mailer module for sending emails.

  In development, emails are previewed at /dev/mailbox instead of being sent.
  """
  use Swoosh.Mailer, otp_app: :zefyrlab
end
