import { useState, type MouseEvent, type ComponentProps } from "react";
import { useLogin, useNotify } from "ra-core";
import { Button } from "@/components/ui/button";
import { Spinner } from "@/components/ui/spinner";

export const GoogleOAuthButton = ({
  children,
  domain,
  redirect: redirectTo,
  ...props
}: GoogleOAuthButtonProps) => {
  const login = useLogin();
  const notify = useNotify();
  const [isPending, setIsPending] = useState(false);

  const handleClick = (event: MouseEvent<HTMLButtonElement>) => {
    event.preventDefault();
    setIsPending(true);
    login(
      { oauthProvider: "google", domain },
      redirectTo ?? window.location.toString(),
    ).catch((error) => {
      setIsPending(false);
      // The authProvider always rejects for OAuth login but there will be no
      // error if the call actually succeeds. This avoids react-admin redirecting
      // immediately to the provided redirect prop before users are redirected to
      // the OAuth provider.
      if (error) {
        notify(
          typeof error === "string"
            ? error
            : typeof error === "undefined" || !error.message
              ? "ra.auth.sign_in_error"
              : error.message,
          {
            type: "error",
            messageArgs: {
              _:
                typeof error === "string"
                  ? error
                  : error && error.message
                    ? error.message
                    : undefined,
            },
          },
        );
      }
    });
  };

  return (
    <Button type="button" onClick={handleClick} disabled={isPending} {...props}>
      {children}
      {isPending ? (
        <Spinner
          className="text-primary-foreground size-4"
          data-icon="inline-start"
        />
      ) : null}
    </Button>
  );
};

export type GoogleOAuthButtonProps = {
  domain?: string;
  redirect?: string;
} & ComponentProps<typeof Button>;
