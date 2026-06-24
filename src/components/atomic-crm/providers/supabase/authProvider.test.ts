import { getAuthProvider } from "./authProvider";

const signInWithOAuth = vi.hoisted(() =>
  vi.fn(async (_options?: any): Promise<any> => ({ data: {}, error: null })),
);
const signInWithSSO = vi.hoisted(() =>
  vi.fn(async (_options?: any): Promise<any> => ({ data: {}, error: null })),
);

vi.mock("./supabase", () => ({
  getSupabaseClient: () => ({
    auth: {
      signInWithOAuth,
      signInWithSSO,
      getSession: async () => ({ data: { session: null }, error: null }),
    },
    from: () => ({
      select: () => ({ data: [], error: null }),
    }),
  }),
}));

describe("getAuthProvider login", () => {
  beforeEach(() => {
    signInWithOAuth.mockClear();
    signInWithSSO.mockClear();
  });

  it("calls signInWithOAuth with the google provider and hd domain hint", async () => {
    // Arrange
    const authProvider = getAuthProvider();

    // Act
    await authProvider.login({
      oauthProvider: "google",
      domain: "goalkeeper.com",
    });

    // Assert
    expect(signInWithOAuth).toHaveBeenCalledTimes(1);
    const arg = signInWithOAuth.mock.calls[0][0];
    expect(arg.provider).toBe("google");
    expect(arg.options.queryParams.hd).toBe("goalkeeper.com");
    expect(arg.options.queryParams.prompt).toBe("select_account");
    expect(arg.options.redirectTo).toContain("/auth-callback.html");
  });

  it("omits the hd query param when no domain is provided", async () => {
    // Arrange
    const authProvider = getAuthProvider();

    // Act
    await authProvider.login({ oauthProvider: "google" });

    // Assert
    const arg = signInWithOAuth.mock.calls[0][0];
    expect(arg.options.queryParams.hd).toBeUndefined();
    expect(signInWithSSO).not.toHaveBeenCalled();
  });

  it("throws when the OAuth provider returns an error", async () => {
    // Arrange
    signInWithOAuth.mockResolvedValueOnce({
      data: {},
      error: new Error("oauth boom"),
    });
    const authProvider = getAuthProvider();

    // Act / Assert
    await expect(
      authProvider.login({ oauthProvider: "google", domain: "goalkeeper.com" }),
    ).rejects.toThrow("oauth boom");
  });
});
