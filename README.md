# IetiPark Web

Aplicació web desenvolupada amb **Flutter** que permet visualitzar en temps real la partida que s'està jugant al joc **IetiPark**.

## Descripció

IetiPark Web actua com a visor web del joc [IetiPark (LibGDX)](https://github.com/alejandroenti/IetiPark-AppLibgdx), permetent als usuaris seguir l'estat de la partida en curs directament des del navegador. Utilitza **WebSockets** per connectar-se amb el servidor del joc i rebre actualitzacions en temps real de l'estat de la partida.

## Tecnologies

- [Flutter](https://flutter.dev/) — Framework multiplataforma amb suport web
- [Dart](https://dart.dev/) — Llenguatge de programació
- **WebSockets** — Comunicació bidireccional en temps real amb el servidor

## Requisits previs

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (canal stable)
- Un navegador web compatible (Chrome recomanat)

## Instal·lació

```bash
# Clonar el repositori
git clone https://github.com/alejandroenti/IetiPark-Web.git
cd IetiPark-Web

# Instal·lar dependències
flutter pub get
```

## Execució

```bash
# Executar en mode web
flutter run -d chrome
```

## Projectes relacionats

- [IetiPark - App LibGDX](https://github.com/alejandroenti/IetiPark-AppLibgdx) — Joc principal desenvolupat amb LibGDX
- [IetiPark - Server](https://github.com/alejandroenti/IetiPark-AppLibgdx) — Servidor de s'encarrega de la comunicació del joc IetiPark fent servir NodeJS

## Llicència

Aquest projecte està llicenciat sota la [GNU General Public License v3.0](LICENSE).
