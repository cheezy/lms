defmodule LmsWeb.LocaleIntegrationTest do
  use LmsWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Lms.CompaniesFixtures
  import Lms.AccountsFixtures
  import Lms.TrainingFixtures
  import Lms.LearningFixtures

  describe "Dashboard in French" do
    setup %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = conn |> log_in_user(admin) |> put_session(:locale, "fr")

      %{conn: conn, company: company, admin: admin}
    end

    test "renders French headings and stats", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Tableau de bord"
      assert html =~ "Total des employés"
      assert html =~ "Taux de complétion"
      assert html =~ "Actions rapides"
    end

    test "renders French quick action links", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/dashboard")

      assert has_element?(view, "a[href='/admin/employees']", "Ajouter un employé")
      assert has_element?(view, "a[href='/courses/new']", "Créer un cours")
      assert has_element?(view, "a[href='/admin/enrollments']", "Gérer les inscriptions")
    end

    test "renders French empty states", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Aucune inscription pour le moment"
      assert html =~ "Aucune complétion pour le moment"
      assert html =~ "Aucun retard"
    end

    test "renders French nav links in header", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/dashboard")

      assert html =~ "Tableau de bord"
      assert html =~ "Employés"
      assert html =~ "Cours"
      assert html =~ "Inscriptions"
      assert html =~ "Se déconnecter"
      assert html =~ "Paramètres"
    end
  end

  describe "Employees page in French" do
    setup %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = conn |> log_in_user(admin) |> put_session(:locale, "fr")

      %{conn: conn, company: company, admin: admin}
    end

    test "renders French headings and buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/employees")

      assert html =~ "Employés"
      assert html =~ "Inviter un employé"
      assert html =~ "Import en masse"
    end

    test "renders French table headers", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)

      {:ok, _view, html} = live(conn, ~p"/admin/employees")

      assert html =~ "Nom"
      assert html =~ "Courriel"
      assert html =~ "Rôle"
      assert html =~ "Statut"
    end

    test "renders French status badges", %{conn: conn, company: company} do
      _employee = user_with_role_fixture(:employee, company.id)

      {:ok, _view, html} = live(conn, ~p"/admin/employees")

      assert html =~ "Actif"
    end

    test "renders French empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/employees")

      assert html =~ "Aucun employé pour le moment"
    end
  end

  describe "Enrollments page in French" do
    setup %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = conn |> log_in_user(admin) |> put_session(:locale, "fr")

      %{conn: conn, company: company, admin: admin}
    end

    test "renders French headings and buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Inscriptions"
      assert html =~ "Inscrire des employés"
    end

    test "renders French table headers", %{conn: conn, company: company} do
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company_id: company.id})
      enrollment_fixture(%{user: employee, course: course})

      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Employé"
      assert html =~ "Cours"
      assert html =~ "Date limite"
      assert html =~ "Progression"
    end

    test "renders French empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Aucune inscription pour le moment"
    end

    test "renders French status filters", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/enrollments")

      assert html =~ "Tous les statuts"
      assert html =~ "Non commencé"
      assert html =~ "En cours"
      assert html =~ "Terminé"
      assert html =~ "En retard"
    end
  end

  describe "Course list page in French" do
    setup %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = conn |> log_in_user(admin) |> put_session(:locale, "fr")

      %{conn: conn, company: company, admin: admin}
    end

    test "renders French headings and buttons", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses")

      assert html =~ "Cours"
      assert html =~ "Nouveau cours"
    end

    test "renders French empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses")

      assert html =~ "Aucun cours pour le moment"
      assert html =~ "Créez votre premier cours pour commencer"
    end

    test "renders French status filters", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses")

      assert html =~ "Tous les statuts"
      assert html =~ "Brouillon"
      assert html =~ "Publié"
      assert html =~ "Archivé"
    end

    test "renders French action buttons for courses", %{
      conn: conn,
      company: company,
      admin: admin
    } do
      _course = course_fixture(%{company: company, creator: admin})

      {:ok, _view, html} = live(conn, ~p"/courses")

      assert html =~ "Modifier"
    end
  end

  describe "Course form in French" do
    setup %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      conn = conn |> log_in_user(admin) |> put_session(:locale, "fr")

      %{conn: conn, company: company, admin: admin}
    end

    test "renders French new course form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/courses/new")

      assert html =~ "Nouveau cours"
      assert html =~ "Titre"
      assert html =~ "Description"
      assert html =~ "Image de couverture"
      assert html =~ "Enregistrer le cours"
      assert html =~ "Retour aux cours"
    end

    test "renders French edit course form", %{conn: conn, company: company, admin: admin} do
      course = course_fixture(%{company: company, creator: admin})

      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/edit")

      assert html =~ "Modifier le cours"
    end
  end

  describe "Course editor in French" do
    setup %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      course = course_fixture(%{company: company, creator: admin})
      conn = conn |> log_in_user(admin) |> put_session(:locale, "fr")

      %{conn: conn, course: course}
    end

    test "renders French editor headings", %{conn: conn, course: course} do
      {:ok, _view, html} = live(conn, ~p"/courses/#{course.id}/editor")

      assert html =~ "Éditeur de cours"
      assert html =~ "Contenu"
      assert html =~ "Aucun chapitre pour le moment"
    end
  end

  describe "My Learning page in French" do
    setup %{conn: conn} do
      company = company_fixture()
      employee = user_with_role_fixture(:employee, company.id)
      conn = conn |> log_in_user(employee) |> put_session(:locale, "fr")

      %{conn: conn, company: company, employee: employee}
    end

    test "renders French headings and description", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my-learning")

      assert html =~ "Mon apprentissage"
      assert html =~ "Reprenez là où vous en étiez"
    end

    test "renders French empty state", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my-learning")

      assert html =~ "Vous n&#39;êtes inscrit à aucun cours pour le moment"
    end

    test "renders French nav link for employee", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/my-learning")

      assert html =~ "Mon apprentissage"
    end
  end

  describe "Course viewer in French" do
    setup %{conn: conn} do
      company = company_fixture()
      admin = user_with_role_fixture(:company_admin, company.id)
      employee = user_with_role_fixture(:employee, company.id)
      course = course_fixture(%{company: company, creator: admin, status: :published})
      enrollment = enrollment_fixture(%{user: employee, course: course})
      conn = conn |> log_in_user(employee) |> put_session(:locale, "fr")

      %{conn: conn, course: course, enrollment: enrollment}
    end

    test "renders French course viewer labels", %{conn: conn, course: course} do
      {:ok, _view, html} = live(conn, ~p"/my-learning/#{course.id}")

      assert html =~ "Navigation"
      assert html =~ "Retour à Mon apprentissage"
      assert html =~ "Ce cours n&#39;a pas encore de leçons"
    end
  end

  describe "Company registration in French" do
    setup %{conn: conn} do
      conn = conn |> Phoenix.ConnTest.init_test_session(%{}) |> put_session(:locale, "fr")

      %{conn: conn}
    end

    test "renders French registration form", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies/register")

      assert html =~ "Enregistrez votre entreprise"
      assert html =~ "Créez votre organisation et votre compte administrateur pour commencer"
      assert html =~ "Nom de l&#39;entreprise"
      assert html =~ "Nom complet"
      assert html =~ "Courriel"
      assert html =~ "Mot de passe"
      assert html =~ "Confirmer le mot de passe"
      assert html =~ "Créer un compte"
    end

    test "renders French login link", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/companies/register")

      assert html =~ "Vous avez déjà un compte"
      assert html =~ "Se connecter"
    end
  end

  describe "System admin company list in French" do
    setup %{conn: conn} do
      admin = user_with_role_fixture(:system_admin)
      conn = conn |> log_in_user(admin) |> put_session(:locale, "fr")

      %{conn: conn}
    end

    test "renders French headings", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/companies")

      assert html =~ "Administration système"
      assert html =~ "Entreprises"
    end

    test "renders French nav link for companies", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/companies")

      assert html =~ "Entreprises"
    end
  end

  describe "Landing page in French" do
    setup %{conn: conn} do
      conn = conn |> Phoenix.ConnTest.init_test_session(%{}) |> put_session(:locale, "fr")

      %{conn: conn}
    end

    test "renders French navigation links", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Fonctionnalités"
      assert html =~ "Comment ça marche"
      assert html =~ "Se connecter"
      assert html =~ "Commencer"
    end

    test "renders French hero section", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Donnez à votre équipe"
      assert html =~ "les moyens de se former et de"
      assert html =~ "qu&#39;ils termineront vraiment"
    end

    test "renders French features section", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Tout ce dont vous avez besoin pour former votre équipe"
      assert html =~ "Créateur de cours simple"
      assert html =~ "Suivi de la progression"
      assert html =~ "Gestion d&#39;équipe"
      assert html =~ "Déploiement flexible"
    end

    test "renders French how it works section", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Opérationnel en trois étapes"
      assert html =~ "Créer"
      assert html =~ "Inviter"
      assert html =~ "Suivre"
    end

    test "renders French CTA section", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Prêt à élever votre équipe"
      assert html =~ "Commencer gratuitement"
    end

    test "renders French footer", %{conn: conn} do
      conn = get(conn, ~p"/")
      html = html_response(conn, 200)

      assert html =~ "Tous droits réservés."
    end
  end

  describe "Login page in French" do
    setup %{conn: conn} do
      conn = conn |> Phoenix.ConnTest.init_test_session(%{}) |> put_session(:locale, "fr")

      %{conn: conn}
    end

    test "renders French login form", %{conn: conn} do
      conn = get(conn, ~p"/users/log-in")
      html = html_response(conn, 200)

      assert html =~ "Bon retour"
      assert html =~ "Vous n&#39;avez pas de compte"
      assert html =~ "Inscrivez-vous"
      assert html =~ "Mot de passe"
      assert html =~ "Se connecter"
    end
  end

  describe "Registration page in French" do
    setup %{conn: conn} do
      conn = conn |> Phoenix.ConnTest.init_test_session(%{}) |> put_session(:locale, "fr")

      %{conn: conn}
    end

    test "renders French registration form", %{conn: conn} do
      conn = get(conn, ~p"/users/register")
      html = html_response(conn, 200)

      assert html =~ "Créez votre compte"
      assert html =~ "Déjà inscrit"
      assert html =~ "Créer un compte"
    end
  end

  describe "Settings page in French" do
    setup %{conn: conn} do
      company = company_fixture()
      user = user_with_role_fixture(:company_admin, company.id)
      conn = conn |> log_in_user(user) |> put_session(:locale, "fr")

      %{conn: conn}
    end

    test "renders French settings headings and labels", %{conn: conn} do
      conn = get(conn, ~p"/users/settings")
      html = html_response(conn, 200)

      assert html =~ "Paramètres du compte"
      assert html =~ "Profil"
      assert html =~ "Changer le courriel"
      assert html =~ "Changer le mot de passe"
    end
  end

  describe "Gettext unit test" do
    test "setting locale to fr returns French translations" do
      Gettext.put_locale("fr")

      assert Gettext.get_locale() == "fr"
      assert Gettext.gettext(LmsWeb.Gettext, "Dashboard") == "Tableau de bord"
      assert Gettext.gettext(LmsWeb.Gettext, "Employees") == "Employés"
      assert Gettext.gettext(LmsWeb.Gettext, "Courses") == "Cours"
      assert Gettext.gettext(LmsWeb.Gettext, "Enrollments") == "Inscriptions"
      assert Gettext.gettext(LmsWeb.Gettext, "My Learning") == "Mon apprentissage"
    end
  end
end
