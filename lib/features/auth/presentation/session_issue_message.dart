import '../domain/session.dart';

String sessionIssueMessage(SessionIssue? issue, {required bool french}) {
  return switch (issue) {
    SessionIssue.profileUnlinked =>
      french
          ? 'Votre compte est connecté, mais aucun profil HEALTH’YS n’y est encore associé. Contactez votre établissement.'
          : 'You are signed in, but no HEALTH’YS profile is linked to your account yet. Contact your organization.',
    SessionIssue.remoteLogout =>
      french
          ? 'Vous êtes déconnecté de cette application. La session du navigateur n’a pas pu être fermée. Réessayez la déconnexion.'
          : 'You are signed out of this app. Your browser session could not be closed. Try signing out again.',
    SessionIssue.storage =>
      french
          ? 'La session sécurisée n’a pas pu être supprimée. Réessayez la déconnexion.'
          : 'Your secure session could not be removed. Try signing out again.',
    SessionIssue.authentication =>
      french
          ? 'La connexion a échoué. Réessayez.'
          : 'Sign-in failed. Try again.',
    SessionIssue.connectivity || null =>
      french
          ? 'Connexion indisponible. Vérifiez votre réseau et réessayez.'
          : 'Connection unavailable. Check your network and try again.',
  };
}
