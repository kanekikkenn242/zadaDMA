import Foundation

class Localization {
    static let shared = Localization()
    
    private let dict: [String: [String: String]] = [
        "English": [
            "home": "Home", "settings": "Settings", "device_status": "Device status",
            "hardware": "Hardware model", "ios": "iOS Version", "exploit": "Exploit compatibility",
            "supported": "Supported", "profile": "Profile", "support": "Support",
            "no_membership": "No membership", "activate_key": "Activate key",
            "enter_key": "Enter your access key", "your_key": "Your key", "activate": "Activate key",
            "support_center": "Support Center", "discord_sup": "Discord support", "discord_ann": "Discord announcements",
            "check_status": "Check status", "language": "Language", "appearance": "Appearance",
            "system": "System", "light": "Light", "dark": "Dark", "game": "Game",
            "tunnel": "Tunnel connection", "pairing": "Pairing status", "compat": "iOS 27 pairing compatibility",
            "not_conn": "Not connected", "no_file": "No pairing file", "supported_ios": "Supported by iOS",
            "open_vpn": "Open LocalDevVPN to connect", "import_pair": "Import pairing file",
            "verified": "Verified versions", "cert_req": "Certificate requirements", "next": "Next", "back": "Back", "finish": "Finish", "done": "Done", "close": "Close",
            "choose_lang": "Choose your language", "welcome": "Welcome to zadaDMA", "dev": "Developed by zadaDMA", "initial": "Initial setup"
        ],
        "Español": [
            "home": "Inicio", "settings": "Ajustes", "device_status": "Estado del dispositivo",
            "hardware": "Modelo de hardware", "ios": "Versión de iOS", "exploit": "Compatibilidad de exploit",
            "supported": "Compatible", "profile": "Perfil", "support": "Soporte",
            "no_membership": "Sin membresía", "activate_key": "Activar clave",
            "enter_key": "Ingrese su clave", "your_key": "Su clave", "activate": "Activar clave",
            "support_center": "Centro de soporte", "discord_sup": "Soporte de Discord", "discord_ann": "Anuncios de Discord",
            "check_status": "Verificar estado", "language": "Idioma", "appearance": "Apariencia",
            "system": "Sistema", "light": "Claro", "dark": "Oscuro", "game": "Juego",
            "tunnel": "Conexión del túnel", "pairing": "Estado de emparejamiento", "compat": "Compatibilidad de iOS 27",
            "not_conn": "No conectado", "no_file": "Sin archivo", "supported_ios": "Compatible con iOS",
            "open_vpn": "Abrir LocalDevVPN", "import_pair": "Importar archivo",
            "verified": "Versiones verificadas", "cert_req": "Requisitos de certificado", "next": "Siguiente", "back": "Atrás", "finish": "Finalizar", "done": "Hecho", "close": "Cerrar",
            "choose_lang": "Elige tu idioma", "welcome": "Bienvenido a zadaDMA", "dev": "Desarrollado por zadaDMA", "initial": "Configuración inicial"
        ],
        "Português": [
            "home": "Início", "settings": "Configurações", "device_status": "Status do dispositivo",
            "hardware": "Modelo de hardware", "ios": "Versão do iOS", "exploit": "Compatibilidade do exploit",
            "supported": "Suportado", "profile": "Perfil", "support": "Suporte",
            "no_membership": "Sem assinatura", "activate_key": "Ativar chave",
            "enter_key": "Digite sua chave", "your_key": "Sua chave", "activate": "Ativar chave",
            "support_center": "Central de suporte", "discord_sup": "Suporte no Discord", "discord_ann": "Anúncios no Discord",
            "check_status": "Verificar status", "language": "Idioma", "appearance": "Aparência",
            "system": "Sistema", "light": "Claro", "dark": "Escuro", "game": "Jogo",
            "tunnel": "Conexão do túnel", "pairing": "Status do emparelhamento", "compat": "Compatibilidade do iOS 27",
            "not_conn": "Não conectado", "no_file": "Sem arquivo", "supported_ios": "Suportado pelo iOS",
            "open_vpn": "Abrir LocalDevVPN", "import_pair": "Importar arquivo",
            "verified": "Versões verificadas", "cert_req": "Requisitos de certificado", "next": "Próximo", "back": "Voltar", "finish": "Concluir", "done": "Concluído", "close": "Fechar",
            "choose_lang": "Escolha seu idioma", "welcome": "Bem-vindo ao zadaDMA", "dev": "Desenvolvido por zadaDMA", "initial": "Configuração inicial"
        ]
    ]
    
    func translate(_ key: String, lang: String) -> String {
        dict[lang]?[key] ?? dict["English"]?[key] ?? key
    }
}
