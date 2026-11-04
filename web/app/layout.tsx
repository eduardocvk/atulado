import type { Metadata } from "next";
import "./globals.css";

export const metadata: Metadata = {
  title: "A tu lado · Las voces de los tuyos",
  description: "Recibe mensajes de ánimo para escucharlos durante tu carrera.",
  icons: {
    icon: "/favicon.svg",
    shortcut: "/favicon.svg",
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es">
      <body className="antialiased">{children}</body>
    </html>
  );
}
