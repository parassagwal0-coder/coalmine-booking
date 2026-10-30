import './globals.css';
import type {Metadata} from 'next';
export const metadata:Metadata={title:'Coal Mine Campground | Book your stay',description:'RV sites, tent camping, and cabins. Reserve online and pay at the campground.'};
export default function Layout({children}:{children:React.ReactNode}){return <html lang="en"><body><header><a className="brand" href="/">CM <span>Coal Mine Campground<small>RESERVATIONS · CAD</small></span></a><a className="staff-link" href="/admin">Staff sign in →</a></header>{children}<footer>Coal Mine Campground Booking System · Pay at the campground<br/>Reservations and automatic email delivery require completed service setup.</footer></body></html>}
